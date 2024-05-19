cmake_minimum_required(VERSION 3.20)
project("Engin3_Deps")

set(CMAKE_DEBUG_POSTFIX d)

macro(set_option option value)
  set(${option} ${value} CACHE "" INTERNAL FORCE)
endmacro()

# Jolt Options
set_option(FLOATING_POINT_EXCEPTIONS_ENABLED OFF)
set_option(INTERPROCEDURAL_OPTIMIZATION OFF)
set_option(USE_STATIC_MSVC_RUNTIME_LIBRARY OFF)
set_option(TARGET_UNIT_TESTS OFF)
set_option(TARGET_HELLO_WORLD OFF)
set_option(TARGET_PERFORMANCE_TEST OFF)
set_option(TARGET_SAMPLES OFF)
set_option(TARGET_VIEWER OFF)

set_option(VMA_STATIC_VULKAN_FUNCTIONS OFF)
set_option(VMA_DYNAMIC_VULKAN_FUNCTIONS OFF)

set_option(TRACY_ON_DEMAND ON)
set_option(TRACY_CALLSTACK ON)

add_subdirectory(odin-vma/VulkanMemoryAllocator)
add_subdirectory(odin-tracy/tracy)
add_subdirectory(jolt)

add_custom_target(build_libs
    DEPENDS VulkanMemoryAllocator
            TracyClient
            JoltCBinding
    COMMENT "Building all dependencies"
)

# Create a custom target to copy library files to the destination directory
add_custom_target(copy_libs ALL
    COMMENT "Copying library files"
)

# Function to copy library files of a target to the destination directory
function(copy_library target destination)
    add_custom_command(TARGET copy_libs POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE:${target}> "${CMAKE_SOURCE_DIR}/${destination}"
        COMMENT "Copying ${target} library to ${CMAKE_SOURCE_DIR}/${destination}"
    )
endfunction()

copy_library(VulkanMemoryAllocator "odin-vma/lib")
copy_library(TracyClient "odin-tracy/lib")
copy_library(JoltCBinding "jolt/lib")
copy_library(Jolt "jolt/lib")