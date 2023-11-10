#include "solver.cuh"

#include <iostream>
#include <fstream>
#include <string.h>
#include <algorithm>

#include <cuda.h>
#include <nvrtc.h>

/*
 * SolverConfig implementation
*/
bool SolverConfig::validate() const {
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

void SolverConfig::writeTo(std::ofstream out) const {

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
 * Constellation implementation
*/
cuda_constellation Constellation::toCUDAConstellation() {
	cuda_constellation cu;
	cu.ld = ld;
	cu.rd = rd;
	cu.col = col;
	cu.start_ijkl = startIjkl;
	return cu;
}

/*
 * ConstellationsGenerator implementation
*/
ConstellationsGenerator::ConstellationsGenerator(uint8_t N) :
	m_N(N), m_preQueens(0), m_LD(0), m_RD(0), m_subconstellationsCounter(0) {

	m_L = (1 << (m_N - 1));
	m_mask = (m_L << 1) - 1;
}

std::vector<Constellation>& ConstellationsGenerator::genConstellations(uint8_t preQueens) {
	m_preQueens = preQueens;
	uint32_t ld, rd, col, ijkl;
	size_t currentSize;
	const int halfN = (m_N + 1) / 2;

	// calculating start constellations with one Queen on the corner square
	// (N-1,N-1)
	for (uint8_t k = 1; k < m_N - 2; k++) { // j is idx of Queen in last row
		for (uint8_t i = k + 1; i < m_N - 1; i++) { // l is idx of Queen in last col
			// always add the constellation, we can not accidently get symmetric ones
			m_ijkls.insert(toIjkl(i, m_N - 1, k, m_N - 1));

			// occupation of ld, rd according to row 1
			// queens i and k
			ld = (m_L >> (k - 1)) | (m_L >> (i - 1));
			// queens i and l
			rd = (m_L >> (i + 1)) | (m_L >> 1);
			// left border from k, right border from l, also bits i and j from the
			// corresponding
			// queens
			col = 1 | m_L | (m_L >> i);

			// diagonals, that are occupied in the last row by the queen j or l
			// we are going to shift them upwards the board later
			// from queen j and l (same, since queen is in the corner)
			m_LD = 1;
			// from queen k and l
			m_RD = 1 | (1 << k);

			// counter of subconstellations, that arise from setting extra queens
			m_subconstellationsCounter = 0;

			// generate all subconstellations with 5 queens
			setPreQueens(ld, rd, col, k, 0, 1, 3);
			// jam j and k and l together into one integer
			ijkl = toIjkl(i, m_N - 1, k, m_N - 1);

			currentSize = m_constellations.size();

			// ijkl and sym are the same for all subconstellations
			for (uint32_t a = 0; a < m_subconstellationsCounter; a++) {
				uint32_t start = m_constellations.at(currentSize - a - 1).startIjkl;
				m_constellations.at(currentSize - a - 1).startIjkl = start | ijkl;
			}
		}
	}
	// calculate starting constellations for no Queens in corners
	// have a look in the loop above for missing explanations
	for (uint8_t j = 1; j < halfN; j++) { // go through last row
		for (uint8_t l = j + 1; l < m_N - 1; l++) { // go through last col
			for (uint8_t k = m_N - j - 2; k > 0; k--) { // go through first col
				if (k == l) // skip if occupied
					continue;
				for (uint8_t i = j + 1; i < m_N - 1; i++) { // go through first row
					if (i == m_N - 1 - l || i == k) // skip if occupied
						continue;
					// check, if we already found a symmetric constellation
					if (!checkRotations(i, j, k, l)) {
						m_ijkls.insert(toIjkl(i, j, k, l));

						// occupy the board corresponding to the queens on the borders of the
						// board
						ld = (m_L >> (i - 1)) | (1 << (m_N - k));
						rd = (m_L >> (i + 1)) | (1 << (l - 1));
						col = 1 | m_L | (m_L >> j) | (m_L >> i);
						// occupy diagonals of the queens j k l in the last row
						// later we are going to shift them upwards the board
						m_LD = (m_L >> j) | (m_L >> l);
						m_RD = (m_L >> j) | (1 << k);

						// counts all subconstellations
						m_subconstellationsCounter = 0;
						// generate all subconstellations
						setPreQueens(ld, rd, col, k, l, 1, 4);
						// jam j and k and l into one integer
						ijkl = toIjkl(i, j, k, l);

						currentSize = m_constellations.size();

						// jkl and sym and start are the same for all subconstellations
						for (uint32_t a = 0; a < m_subconstellationsCounter; a++) {
							uint32_t start = m_constellations.at(currentSize - a - 1).startIjkl;
							m_constellations.at(currentSize - a - 1).startIjkl = start | ijkl;
						}
					}
				}
			}
		}
	}
	return m_constellations;
}

void ConstellationsGenerator::setPreQueens(uint32_t ld, uint32_t rd, uint32_t col, uint8_t k, uint8_t l, uint8_t row, uint8_t queens) {
	// in row k and l just go further
	if (row == k || row == l) {
		setPreQueens(ld << 1, rd >> 1, col, k, l, row + 1, queens);
		return;
	}
	// add queens until we have preQueens queens
	if (queens == m_preQueens) {
		// add the subconstellations to the list
		// id=-1 signals that this constellation does not have a specific id
		// solutions=-1 signals that this constellation has not been solved yet
		Constellation c(-1, ld, rd, col, row << 20, -1);
		m_constellations.push_back(c);
		m_subconstellationsCounter++;
		return;
	}
	// if not done or row k or l, just place queens and occupy the board and go
	// further
	else {
		int free = ~(ld | rd | col | (m_LD >> (m_N - 1 - row)) | (m_RD << (m_N - 1 - row))) & m_mask;
		int bit;

		while (free > 0) {
			bit = free & (-free);
			free -= bit;
			setPreQueens((ld | bit) << 1, (rd | bit) >> 1, col | bit, k, l, row + 1, queens + 1);
		}
	}
}

uint32_t ConstellationsGenerator::toIjkl(uint8_t i, uint8_t j, uint8_t k, uint8_t l) const {
	return (i << 15) + (j << 10) + (k << 5) + l;
}

bool ConstellationsGenerator::checkRotations(uint8_t i, uint8_t j, uint8_t k, uint8_t l) const {
	// rot90
	if (m_ijkls.count(((m_N - 1 - k) << 15) + ((m_N - 1 - l) << 10) + (j << 5) + i))
		return true;

	// rot180
	if (m_ijkls.count(((m_N - 1 - j) << 15) + ((m_N - 1 - i) << 10) + ((m_N - 1 - l) << 5) + m_N - 1 - k))
		return true;

	// rot270
	if (m_ijkls.count((l << 15) + (k << 10) + ((m_N - 1 - i) << 5) + m_N - 1 - j))
		return true;

	return false;
}

void ConstellationsGenerator::addPseudoConstellation(std::vector<Constellation>& constellations, uint32_t ijkl) {
	constellations.push_back(Constellation(-1, (1 << m_N) - 1, (1 << m_N) - 1, (1 << m_N) - 1, (69 << 20) | ijkl, -2));
}

std::vector<Constellation> ConstellationsGenerator::fillWithPseudoConstellations(std::vector<Constellation>& constellations, uint16_t blockSize) {
	std::sort(constellations.begin(), constellations.end());
	std::vector<Constellation> newConstellations;
	int currentJkl = constellations.at(0).startIjkl & ((1 << 15) - 1);
	for (const auto& c : constellations) {
		// iterate through constellations, add each remaining constellations and fill up
		// each group of ijkl till its dividable by workgroup-size
		if (c.solutions >= 0)
			continue;

		if ((c.startIjkl & ((1 << 15) - 1)) != currentJkl) { // check if new ijkl is found
			while (newConstellations.size() % blockSize != 0) {
				addPseudoConstellation(newConstellations, currentJkl);
			}
			currentJkl = c.startIjkl & ((1 << 15) - 1);
		}
		newConstellations.push_back(c);
	}
	while (newConstellations.size() % blockSize != 0) {
		addPseudoConstellation(newConstellations, currentJkl);
	}
	return newConstellations;
}

/*
 * CUDASolver::Device implementation
*/
std::vector<CUDASolver::Device> CUDASolver::m_availableDevices;

void CUDASolver::Device::createCUDAObjects() {
	checkCUErr(cuCtxCreate(&context, 0, device));
	checkCUErr(cuStreamCreate(&xStream, 0));
	checkCUErr(cuStreamCreate(&memStream, 0));
	checkCUErr(cuStreamCreate(&updateStream, 0));
	checkCUErr(cuEventCreate(&startEvent, 0));
	checkCUErr(cuEventCreate(&endEvent, 0));
	checkCUErr(cuEventCreate(&memEvent, 0));
	checkCUErr(cuEventCreate(&updateEvent, 0));
}

void CUDASolver::Device::destroyCUDAObjects() {
	checkCUErr(cuEventDestroy(startEvent));
	checkCUErr(cuEventDestroy(endEvent));
	checkCUErr(cuEventDestroy(memEvent));
	checkCUErr(cuEventDestroy(updateEvent));
	checkCUErr(cuStreamDestroy(xStream));
	checkCUErr(cuStreamDestroy(memStream));
	checkCUErr(cuStreamDestroy(updateStream));
	checkCUErr(cuCtxDestroy(context));
}

/*
 * CUDASolver implementation
*/
CUDASolver::CUDASolver(uint8_t N) : Solver(N) {
	static bool initialized;
	if (!initialized) {
		initialized = true;
		checkCUErr(cuInit(0));
		fetchAvailableDevices();
	}
}

void CUDASolver::checkCUErr(CUresult err) {
	if (err != CUDA_SUCCESS) {
		if(err == CUDA_ERROR_NOT_INITIALIZED)
			throw std::runtime_error("CUDA was not initialized");

		const char* name;
		int err2 = cuGetErrorName(err, &name);
		if(err2 == CUDA_ERROR_INVALID_VALUE)
			throw std::runtime_error("unknown CUDA error code: " + std::to_string(err));

		const char* description;
		cuGetErrorName(err, &description);

		std::string errMsg = name + std::string(": ") + description;
		throw std::runtime_error(std::string("CUDA error: " + errMsg));
	}
}

void CUDASolver::checkNVRTCErr(nvrtcResult err) {
	if (err != NVRTC_SUCCESS) {
		const char* description = nvrtcGetErrorString(err);
		if (!strcmp(description, "NVRTC_ERROR unknown"))
			throw std::runtime_error("unknown NVRTC error code: " + std::to_string(err));
		throw std::runtime_error(std::string("NVRTC error: " + std::string(description)));
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

std::vector<std::string> CUDASolver::getAvailableDevices() const {
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

void CUDASolver::setPreQueens(uint8_t preQueens) {
	m_preQueens = preQueens;
}

void CUDASolver::compileProgram(const char* kernelSourcePath) {
	std::ifstream kernelSourceFile(kernelSourcePath);
	std::string kernelSource((std::istreambuf_iterator<char>(kernelSourceFile)), (std::istreambuf_iterator<char>()));
	nvrtcProgram program;
	checkNVRTCErr(nvrtcCreateProgram(&program, &kernelSource[0], "nqfaf", 0, NULL, NULL));

	std::string optN = "-D N=" + std::to_string(m_N);
	std::string optBlockSize = "-D BLOCK_SIZE=" + std::to_string(m_device.config.blockSize);
	const char* const options[]{optN.c_str(), optBlockSize.c_str()};
	nvrtcResult err = nvrtcCompileProgram(program, 2, options);
	if (err != NVRTC_SUCCESS) {
		if (err == NVRTC_ERROR_COMPILATION) {
			size_t logSize;
			checkNVRTCErr(nvrtcGetProgramLogSize(program, &logSize));
			if (logSize > 1) {
				char* log = new char[logSize];
				checkNVRTCErr(nvrtcGetProgramLog(program, log));
				throw std::invalid_argument("kernel source code could not be compiled: " + std::string(log));
			}
		}
		else {
			checkNVRTCErr(err);
		}
	}
	
	size_t ptxSize;
	checkNVRTCErr(nvrtcGetPTXSize(program, &ptxSize));
	char* ptx = new char[ptxSize];
	checkNVRTCErr(nvrtcGetPTX(program, ptx));
	CUmodule module;
	checkCUErr(cuModuleLoadData(&module, (const void*)ptx));
	checkCUErr(cuModuleGetFunction(&function, module, "nqfaf"));
}

void CUDASolver::solve() {
	ConstellationsGenerator generator(m_N);
	m_constellations = generator.genConstellations(m_preQueens);
	m_constellations = generator.fillWithPseudoConstellations(m_constellations, m_device.config.blockSize);

	m_device.createCUDAObjects();
	compileProgram("kernel.cu");

	// write buffers to GPU
	size_t constellationsSize = m_constellations.size() * sizeof(cuda_constellation);
	cuda_constellation* h_constellations = (cuda_constellation*)malloc(constellationsSize);
	if (h_constellations == NULL) {
		throw std::runtime_error("could not allocate memory for the host array containing the devices constellations");
	}
	std::vector<Constellation>::iterator it;
	int i;
	for (it = m_constellations.begin(), i = 0; it < m_constellations.end(); it++, i++) {
		h_constellations[i] = (*it).toCUDAConstellation();
	}
	size_t resultsSize = m_constellations.size() * sizeof(uint64_t);
	uint64_t* h_results = (uint64_t*)malloc(resultsSize);
	if (h_results == NULL) {
		throw std::runtime_error("could not allocate memory for the host array containing the results of the constellations");
	}
	for (it = m_constellations.begin(), i = 0; it < m_constellations.end(); it++, i++) {
		h_results[i] = (*it).solutions;
	}

	CUdeviceptr d_constellations;
	checkCUErr(cuMemAlloc(&d_constellations, constellationsSize));
	CUdeviceptr d_results;
	checkCUErr(cuMemAlloc(&d_results, resultsSize));

	checkCUErr(cuMemcpyHtoD(d_constellations, h_constellations, constellationsSize));
	checkCUErr(cuMemcpyHtoD(d_results, h_results, resultsSize));
	// ---

	// launch kernel
	// ...

	checkCUErr(cuMemFree(d_constellations));
	checkCUErr(cuMemFree(d_results));
	if (h_constellations)
		free(h_constellations);
	if (h_results)
		free(h_results);
	m_device.destroyCUDAObjects();
}

uint64_t CUDASolver::getDuration() const {
	return 69;
}

float CUDASolver::getProgress() const {
	return 1.234f;
}

int64_t CUDASolver::getSolutions() const {
	return 420;
}
