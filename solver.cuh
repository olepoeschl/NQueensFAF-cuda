#ifndef SOLVER_H
#define SOLVER_H

#include <string>
#include <fstream>
#include <thread>
#include <vector>
#include <unordered_set>

#include <cuda.h>

class SolverConfig {
public:
	uint64_t updateInterval;
	bool autoSaveEnabled, autoDeleteEnabled;
	float autoSavePercentageStep;
	std::string autoSavePath;

	SolverConfig() : 
		updateInterval(128), autoSaveEnabled(false), autoDeleteEnabled(false), 
		autoSavePercentageStep(10), autoSavePath("nqueensfaf{N}.dat") {
	}
	bool validate() const;
	void readFrom(SolverConfig config);
	void readFrom(std::ifstream in);
	void writeTo(std::ofstream out) const;
};

class Solver {
public:
	virtual uint64_t getDuration() const = 0;
	virtual float getProgress() const = 0;
	virtual int64_t getSolutions() const = 0;
	virtual void solve() = 0;
	void solveAsync();
	void waitFor();
	void setN(const uint8_t N) {
		m_N = N;
	}
	void setConfig(const SolverConfig& config) {
		if (!config.validate())
			throw std::invalid_argument("invalid solver config");
		m_config.readFrom(config);
	}
protected:
	Solver() : 
		m_N(0), m_solverThread(NULL) {
	}
	uint8_t m_N;
private:
	std::thread* m_solverThread;
	SolverConfig m_config;
};

class Constellation {
public:
	Constellation(int c_id, int c_ld, int c_rd, int c_col, int c_startijkl, int64_t c_solutions) :
		id(c_id), ld(c_ld), rd(c_rd), col(c_col), startijkl(c_startijkl), solutions(c_solutions) {
	}
	int getÍjkl() const {
		return startijkl & 0b11111111111111111111;
	}
	int id, ld, rd, col, startijkl;
	int64_t solutions;
};

class ConstellationsGenerator {
public:
	ConstellationsGenerator(uint8_t N);
	std::vector<Constellation> genConstellations(uint8_t preQueens);
private:
	void setPreQueens(uint32_t ld, uint32_t rd, uint32_t col, uint8_t k, uint8_t l, uint8_t row, uint8_t queens);
	uint32_t toIjkl(uint8_t i, uint8_t j, uint8_t k, uint8_t l) const;
	bool checkRotations(uint8_t i, uint8_t j, uint8_t k, uint8_t l) const;
	uint8_t m_N, m_preQueens;
	uint32_t m_L, m_mask, m_LD, m_RD;
	uint32_t m_subconstellationsCounter;
	std::vector<Constellation> m_constellations;
	std::unordered_set<uint32_t> m_ijkls;
};

class CUDADeviceConfig {
public:
	uint16_t blockSize;
};

class CUDASolver : public Solver {
public:
	CUDASolver();
	uint64_t getDuration() const;
	float getProgress() const;
	int64_t getSolutions() const;
	void solve();
	std::vector<std::string> getAvailableDevices() const;
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
		char name[50]{};
		CUDADeviceConfig config{};
		CUdevice device = 0;
		CUcontext context = 0;
		CUmodule module = 0;
		CUfunction function = 0;
	};
	static void checkCUErr(CUresult err);
	static void fetchAvailableDevices();
	static std::vector<Device> m_availableDevices;
	Device m_device;
	std::vector<Constellation> m_constellations;
	std::chrono::high_resolution_clock::time_point m_start, m_end;
};

class SolverException : public std::exception {
public:
	SolverException(const char* msg) : m_msg(msg) {
	}
	char const* what() const {
		return m_msg;
	}
private:
	const char* m_msg;
};

#endif	