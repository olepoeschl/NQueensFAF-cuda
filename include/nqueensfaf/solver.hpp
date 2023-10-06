#ifndef SOLVER_H
#define SOLVER_H

#include <string>
#include <fstream>

class Solver {
	public:
		// virtual template <class T : public Solver> T getConfig() = 0;
		virtual int64_t getDuration() = 0;
		virtual float getProgress() = 0;
		virtual int64_t getSolutions() = 0;
		void solve();
		// ...
	protected:
		Solver();
	private:
		int m_N;
};

class SolverException : public std::exception {
	public:
		SolverException() {
		}
		SolverException(std::string msg) : m_msg(msg) {
		}
		std::string what() {
			return m_msg;
		}
	private:
		std::string m_msg;
};

class Config {
	public:
		long updateInterval;
		bool autoSaveEnabled, autoDeleteEnabled;
		float autoSavePercentageStep;
		std::string autoSavePath;
		
		Config(){
			updateInterval = 128;
			autoSaveEnabled = false;
			autoDeleteEnabled = false;
			autoSavePercentageStep = 10;
			autoSavePath = "nqueensfaf{N}.dat";
		}
		bool validate();
		void from(Config);
		// template <class T : public Config> T from(ifstream);
		void writeTo(std::ofstream);
};

#endif	