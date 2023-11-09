#include <iostream>
#include "solver.cuh"

int main() {
	try {
		CUDASolver cudaSolver = CUDASolver();
		auto deviceNames = cudaSolver.getAvailableDevices();
		std::cout << "available devices:" << std::endl;
		std::cout << "==================" << std::endl;
		for (int i = 0; i < deviceNames.size(); i++) {
			std::cout << "[" << i << "]\t" << deviceNames.at(i) << std::endl;
		}
		int chosenDeviceIndex;
		std::cout << std::endl << "> choose device (index): ";
		std::cin >> chosenDeviceIndex;
		cudaSolver.setDevice(chosenDeviceIndex);
	}
	catch(SolverException e){
		std::cout << "!unexpected solver exception: " << e.what() << std::endl;
	}
	catch (std::runtime_error e) {
		std::cout << "!unexpected runtime error: " << e.what() << std::endl;
	}
	catch (std::exception e) {
		std::cout << "!unexpected exception: " << e.what() << std::endl;
	}
	return 0;
}