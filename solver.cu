#include "solver.cuh"
#include <iostream>
#include <fstream>
#include <cuda.h>

/*
 * SolverConfig implementation
*/
bool SolverConfig::validate() {
	return (updateInterval > 0) && (autoSavePercentageStep > 0 && autoSavePercentageStep <= 100) && (autoSavePath.length() > 0);
}

void SolverConfig::readFrom(SolverConfig config) {
	updateInterval = config.updateInterval;
	autoSaveEnabled = config.autoSaveEnabled;
	autoDeleteEnabled = config.autoDeleteEnabled;
	autoSavePercentageStep = config.autoSavePercentageStep;
	autoSavePath = config.autoSavePath;
}

void SolverConfig::readFrom(std::ifstream in) {

}

void SolverConfig::writeTo(std::ofstream out) {

}

/*
 * Solver implementation
*/
void Solver::solveAsync() {
	m_solverThread = new std::thread(&Solver::solve, this);
}

void Solver::waitFor() {
	if (m_solverThread == NULL)
		throw SolverException("Solver is not running and therefore cannot be waited for!");
	m_solverThread->join();
	delete m_solverThread;
}

/*
 * CUDASolver implementation
*/
CUDASolver::CUDASolver() : Solver() {
	fetchAvailableDevices();
}

void CUDASolver::checkCUErr(CUresult err) {
	if (err != CUDA_SUCCESS) {
		std::string errMsg = "";
		const char* strBuf = NULL;

		int err2 = cuGetErrorName(err, &strBuf);
		if (err2 == CUDA_ERROR_INVALID_VALUE) {
			throw std::runtime_error("unknown CUDA error code: " + err2);
		}
		errMsg.append(strBuf);
		const char* strBuf2 = NULL;
		err2 = cuGetErrorString(err, &strBuf2);
		if (err2 == CUDA_ERROR_INVALID_VALUE) {
			throw std::runtime_error("unknown CUDA error code: " + err2);
		}
		errMsg.append(strBuf2);

		throw std::runtime_error(std::string("CUDA error: " + errMsg));
	}
}

void CUDASolver::fetchAvailableDevices() {
	int deviceCount;
	checkCUErr(cuDeviceGetCount(&deviceCount));
	std::cout << "device count: " << deviceCount << std::endl;
}

void CUDASolver::solve() {
	cuInit(0);
	std::cout << "solving..." << std::endl;
}

int64_t CUDASolver::getDuration() {
	return 69;
}

float CUDASolver::getProgress() {
	return 1.234f;
}

int64_t CUDASolver::getSolutions() {
	return 420;
}
