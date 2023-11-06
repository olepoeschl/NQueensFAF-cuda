#include "solver.hpp"

#include <iostream>

int main(){
	CUDASolver solver;
	solver.solve();
	std::cout << "solver finished" << std::endl;
	return 0;
}