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
	static bool initialized;
	if (!initialized) {
		initialized = true;
		checkCUErr(cuInit(0));
	}
	fetchAvailableDevices();
}

void CUDASolver::checkCUErr(CUresult err) {
	if (err != CUDA_SUCCESS) {
		if(err == CUDA_ERROR_NOT_INITIALIZED)
			throw std::runtime_error("CUDA was not initialized");

		const char* name;
		int err2 = cuGetErrorName(err, &name);
		if(err2 == CUDA_ERROR_INVALID_VALUE)
			throw std::runtime_error("unknown CUDA error code: " + std::to_string(err));
		std::cout << "name: " << name << std::endl;

		const char* description;
		cuGetErrorName(err, &description);
		std::cout << "description: " << description << std::endl;

		std::string errMsg = name + std::string(": ") + description;
		throw std::runtime_error(std::string("CUDA error: " + errMsg));
	}
}

void CUDASolver::fetchAvailableDevices() {
	int deviceCount;
	checkCUErr(cuDeviceGetCount(&deviceCount));
	for (int i = 0; i < deviceCount; i++) {
		Device device;
		checkCUErr(cuDeviceGet(&(device.device), i));
		checkCUErr(cuDeviceGetName(device.name, 50, device.device));
		m_availableDevices.push_back(device);
	}
}

std::vector<std::string> CUDASolver::getAvailableDevices() {
	std::vector<std::string> deviceNames;
	for (const Device& device : m_availableDevices) {
		deviceNames.push_back(device.name);
	}
	return deviceNames;
}

void CUDASolver::setDevice(uint8_t index) {
	if (index >= m_availableDevices.size())
		throw std::invalid_argument("invalid device index");
	m_device = m_availableDevices.at(index);
}

void CUDASolver::solve() {
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
