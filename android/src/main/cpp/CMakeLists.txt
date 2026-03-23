cmake_minimum_required(VERSION 3.22.1)
project(flutter_notemus_native)

add_library(
    flutter_notemus_native
    SHARED
    native_audio_engine.cpp
)

target_compile_features(flutter_notemus_native PRIVATE cxx_std_17)
target_compile_options(flutter_notemus_native PRIVATE -O3 -ffast-math)

find_library(log-lib log)

target_link_libraries(
    flutter_notemus_native
    ${log-lib}
)
