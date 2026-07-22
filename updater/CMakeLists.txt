cmake_minimum_required(VERSION 3.15)
project(solaris_updater CXX C)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_C_STANDARD 99)

# STATIC LINKING OF MSVC C++ RUNTIME (/MT in Release, /MTd in Debug)
# Allows updater.exe to be 100% self-contained and run on clean Windows 10/11 installations
# without the Visual C++ Redistributable package installed (MSVCP140.dll / VCRUNTIME140.dll)
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")

if(MSVC)
    add_compile_options(/W4 /WX- /DUNICODE /D_UNICODE)
endif()

if(MSVC)
    add_executable(updater main.cpp miniz.c resource.rc app.manifest)
else()
    add_executable(updater main.cpp miniz.c)
endif()

target_link_libraries(updater PRIVATE shlwapi ole32 oleaut32 shell32 advapi32 user32)
