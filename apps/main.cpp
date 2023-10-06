#include "solver.hpp"

class SolverImplTest : public Solver {
	public:
		SolverImplTest() : Solver(){
		}
		int64_t getDuration();
		float getProgress();
		int64_t getSolutions();
};

int64_t SolverImplTest::getDuration() {
	return 69;
}

float SolverImplTest::getProgress() {
	return 1.234;
}

int64_t SolverImplTest::getSolutions() {
	return 420;
}

int main(){
	SolverImplTest solver;
	solver.solve();
	return 0;
}