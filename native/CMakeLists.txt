cmake_minimum_required(VERSION 3.21)

project(poptools_terminal LANGUAGES C CXX)

set(CMAKE_AUTOMOC ON)
set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick)

set(LIBVTERM_DIR "${CMAKE_CURRENT_SOURCE_DIR}/third_party/libvterm")
set(LIBVTERM_SOURCES
    "${LIBVTERM_DIR}/src/encoding.c"
    "${LIBVTERM_DIR}/src/keyboard.c"
    "${LIBVTERM_DIR}/src/mouse.c"
    "${LIBVTERM_DIR}/src/parser.c"
    "${LIBVTERM_DIR}/src/pen.c"
    "${LIBVTERM_DIR}/src/screen.c"
    "${LIBVTERM_DIR}/src/state.c"
    "${LIBVTERM_DIR}/src/unicode.c"
    "${LIBVTERM_DIR}/src/vterm.c"
)

add_library(poptools_libvterm STATIC ${LIBVTERM_SOURCES})
target_include_directories(poptools_libvterm PUBLIC
    "${LIBVTERM_DIR}/include"
    PRIVATE
    "${LIBVTERM_DIR}/src"
)
target_compile_definitions(poptools_libvterm PRIVATE _CRT_SECURE_NO_WARNINGS)

add_library(poptools_terminal SHARED
    terminalitem.cpp
    terminalitem.h
)

target_include_directories(poptools_terminal PRIVATE "${LIBVTERM_DIR}/include")
target_compile_definitions(poptools_terminal PRIVATE
    POPTOOLS_TERMINAL_LIBRARY
    _CRT_SECURE_NO_WARNINGS
)
target_link_libraries(poptools_terminal PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    poptools_libvterm
)

set_target_properties(poptools_terminal PROPERTIES
    OUTPUT_NAME "poptools_terminal"
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/out"
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/out"
    ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib"
)

install(TARGETS poptools_terminal
    RUNTIME DESTINATION .
    LIBRARY DESTINATION .
)

include(CTest)
if(BUILD_TESTING)
    add_executable(poptools_libvterm_test terminal_core_test.c)
    target_link_libraries(poptools_libvterm_test PRIVATE poptools_libvterm)
    add_test(NAME poptools_libvterm_test COMMAND poptools_libvterm_test)
endif()
