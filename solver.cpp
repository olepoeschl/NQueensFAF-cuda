#include "solver.hpp"
#include <iostream>
#include <fstream>

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
 * SolverConfig implementation
*/
bool SolverConfig::validate() {
	return true;
}

void SolverConfig::readFrom(SolverConfig config) {

}

void SolverConfig::readFrom(std::ifstream in) {

}

void SolverConfig::writeTo(std::ofstream out) {

}

/*
 * CUDASolver implementation
*/
CUDASolver::CUDASolver() : Solver() {
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
