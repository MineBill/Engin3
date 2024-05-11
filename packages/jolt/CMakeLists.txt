cmake_minimum_required(VERSION 3.20)
project("odin_jolt")

add_subdirectory(JoltPhysics/Build)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
add_library(
    JoltCBinding
        jolt_bind.cpp
)

target_link_libraries(
    JoltCBinding
    STATIC
        Jolt
)