cmake_minimum_required(VERSION 3.22.1)
project("llama_wrapper")

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# llama.cpp source directory
set(LLAMA_DIR ${CMAKE_SOURCE_DIR}/llama.cpp)

# Build llama.cpp as a static library
set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)

# llama.cpp options
set(LLAMA_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_SERVER OFF CACHE BOOL "" FORCE)

# Add llama.cpp subdirectory
add_subdirectory(${LLAMA_DIR} llama_build)

# Create our wrapper shared library
add_library(llama_wrapper SHARED
    llama_wrapper.cpp
)

target_link_libraries(llama_wrapper
    llama
    android
    log
)

target_include_directories(llama_wrapper PRIVATE
    ${LLAMA_DIR}/include
    ${LLAMA_DIR}/ggml/include
    ${LLAMA_DIR}/src
)
