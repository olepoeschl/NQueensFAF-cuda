#version management
cmake_minimum_required(VERSION 3.7...3.27)

if(${CMAKE_VERSION} VERSION_LESS 3.12)
    cmake_policy(VERSION ${CMAKE_MAJOR_VERSION}.${CMAKE_MINOR_VERSION})
endif()

# project info
project(NQueensFAF VERSION 1.0 DESCRIPTION "Fast algorithms for solving the n queens problem." LANGUAGES CXX)

# targets
add_library(solver STATIC src/solver.cpp include/nqueensfaf/solver.hpp)
target_include_directories(solver PUBLIC include/nqueensfaf)

add_executable(main apps/main.cpp)
target_link_libraries(main PUBLIC solver)