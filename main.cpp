#include <iostream>
#include "solver.cuh"

int main() {
	try {
		CUDASolver cudaSolver = CUDASolver(18);
		auto deviceNames = cudaSolver.getAvailableDevices();
		std::cout << "available devices:" << std::endl;
		std::cout << "==================" << std::endl;
		for (int i = 0; i < deviceNames.size(); i++) {
			std::cout << "[" << i << "]\t" << deviceNames.at(i) << std::endl;
		}
		int chosenDeviceIndex = 0;
		std::cout << std::endl << "> choose device (index): ";
		std::cin >> chosenDeviceIndex;
		if (std::cin.fail()) {
			throw std::invalid_argument("device index has to be of type integer");
		}
		cudaSolver.setDevice(chosenDeviceIndex);

		cudaSolver.solve();
		std::cout << "Found " << cudaSolver.getSolutions() << " solutions in " << cudaSolver.getDuration() << " ms" << std::endl;
	}
	catch(SolverException e){
		std::cerr << "! unexpected solver exception: " << e.what() << std::endl;
	}
	catch (std::runtime_error e) {
		std::cerr << "! unexpected runtime error: " << e.what() << std::endl;
	}
	catch (std::exception e) {
		std::cerr << "! unexpected exception: " << e.what() << std::endl;
	}
	return 0;
}