#ifndef SOLVER_H
#define SOLVER_H

#include <string>
#include <fstream>
#include <thread>
#include <vector>
#include <cuda.h>

class SolverConfig {
public:
	long updateInterval;
	bool autoSaveEnabled, autoDeleteEnabled;
	float autoSavePercentageStep;
	std::string autoSavePath;

	SolverConfig() {
		updateInterval = 128;
		autoSaveEnabled = false;
		autoDeleteEnabled = false;
		autoSavePercentageStep = 10;
		autoSavePath = "nqueensfaf{N}.dat";
	}
	bool validate();
	void readFrom(SolverConfig config);
	void readFrom(std::ifstream in);
	void writeTo(std::ofstream out);
};

class Solver {
public:
	virtual int64_t getDuration() = 0;
	virtual float getProgress() = 0;
	virtual int64_t getSolutions() = 0;
	virtual void solve() = 0;
	void solveAsync();
	void waitFor();
	void setN(int N) {
		m_N = N;
	}
	void setConfig(SolverConfig config) {
		if (!config.validate())
			throw std::invalid_argument("invalid solver config");
		m_config.readFrom(config);
	}
protected:
	Solver() {}
private:
	int m_N = 0;
	std::thread* m_solverThread = NULL;
	SolverConfig m_config;
};

class Constellation {
public:
	Constellation(int c_id, int c_ld, int c_rd, int c_col, int c_startijkl, long c_solutions) :
		id(c_id), ld(c_ld), rd(c_rd), col(c_col), startijkl(c_startijkl), solutions(c_solutions) {
	}
	int getÍjkl() {
		return startijkl & 0b11111111111111111111;
	}
	int id, ld, rd, col, startijkl;
	long solutions;
};

class CUDADeviceConfig {
public:
	int16_t blockSize;
};

class CUDASolver : public Solver {
public:
	CUDASolver();
	int64_t getDuration();
	float getProgress();
	int64_t getSolutions();
	void solve();
	std::vector<std::string> getAvailableDevices();
	void setDevice(uint8_t index);
private:
	class Device {
	public:
		void run();
		void createCUObjects();
		void compileProgram();
		void createAndFillBuffers();
		void readResults();
		void destroyCUObjects();
		char name[50];
		CUDADeviceConfig config;
		CUdevice device;
		CUcontext context;
		CUmodule module;
		CUfunction function;
	};
	void checkCUErr(CUresult err);
	void fetchAvailableDevices();
	std::vector<Constellation> m_constellations;
	std::chrono::high_resolution_clock::time_point m_start, m_end;
	std::vector<Device> m_availableDevices;
	Device m_device;
};

class SolverException : public std::exception {
public:
	SolverException(const char* msg) : m_msg(msg) {
	}
	const char* what() {
		return m_msg;
	}
private:
	const char* m_msg;
};

#endif	