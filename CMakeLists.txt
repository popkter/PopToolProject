cmake_minimum_required(VERSION 3.25)
project(UTerminal VERSION 0.1.1 LANGUAGES C CXX)
configure_file(src/uterminal/version.rc.in ${CMAKE_CURRENT_BINARY_DIR}/uterminal-version.rc @ONLY)
file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/version.json "{\"version\":\"${PROJECT_VERSION}\"}\n")
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_C_STANDARD 11)
set(CMAKE_AUTOMOC OFF)
set(CMAKE_AUTORCC ON)
find_package(Qt6 6.10 REQUIRED COMPONENTS Core Gui Widgets Qml Quick QuickControls2 Network Test)
if(MSVC)
  add_compile_options(/utf-8 /W4)
  add_compile_definitions(NOMINMAX WIN32_LEAN_AND_MEAN _WIN32_WINNT=0x0A00)
endif()
set(VTERM native/third_party/libvterm)
add_library(uterminal_vterm STATIC
  ${VTERM}/src/encoding.c ${VTERM}/src/keyboard.c ${VTERM}/src/mouse.c
  ${VTERM}/src/parser.c ${VTERM}/src/pen.c ${VTERM}/src/screen.c
  ${VTERM}/src/state.c ${VTERM}/src/unicode.c ${VTERM}/src/vterm.c)
target_include_directories(uterminal_vterm PUBLIC ${VTERM}/include PRIVATE ${VTERM}/src)
target_compile_definitions(uterminal_vterm PRIVATE _CRT_SECURE_NO_WARNINGS)
qt6_wrap_cpp(UT_CORE_MOC
  src/uterminal/presentation/settings.h
  src/uterminal/presentation/scripts.h
  src/uterminal/application/plugins.h
  src/uterminal/application/updates.h
  src/uterminal/application/pythonenvironment.h
  src/uterminal/infrastructure/processrunner.h
  src/uterminal/infrastructure/conpty.h)
add_library(uterminal_core STATIC ${UT_CORE_MOC}
  src/uterminal/domain/parameters.cpp
  src/uterminal/infrastructure/storage.cpp
  src/uterminal/infrastructure/scriptfiles.cpp
  src/uterminal/infrastructure/updatepackage.cpp
  src/uterminal/infrastructure/conpty.cpp
  src/uterminal/infrastructure/processrunner.cpp
  src/uterminal/presentation/settings.cpp
  src/uterminal/application/plugins.cpp
  src/uterminal/application/updates.cpp
  src/uterminal/application/pythonenvironment.cpp
  src/uterminal/presentation/scripts.cpp)
target_include_directories(uterminal_core PUBLIC src/uterminal)
target_compile_definitions(uterminal_core PUBLIC UTERMINAL_VERSION="${PROJECT_VERSION}")
target_link_libraries(uterminal_core PUBLIC Qt6::Core Qt6::Gui Qt6::Network)
qt6_wrap_cpp(UT_TERMINAL_MOC src/uterminal/presentation/terminalitem.h src/uterminal/presentation/sessions.h src/uterminal/application/executions.h src/uterminal/presentation/scripthighlighter.h src/uterminal/presentation/scriptediting.h)
add_library(uterminal_terminal STATIC ${UT_TERMINAL_MOC}
  src/uterminal/presentation/scripthighlighter.cpp
  src/uterminal/presentation/scriptediting.cpp
  src/uterminal/presentation/terminalitem.cpp src/uterminal/presentation/sessions.cpp src/uterminal/application/executions.cpp)
target_link_libraries(uterminal_terminal PUBLIC uterminal_core uterminal_vterm Qt6::Quick Qt6::Qml)
qt6_wrap_cpp(UT_APP_MOC src/uterminal/presentation/app.h)
add_executable(UTerminal WIN32 src/uterminal/main.cpp src/uterminal/presentation/app.cpp ${UT_APP_MOC})
add_executable(UTerminalUpdateRunner WIN32 src/uterminal/update_runner.cpp src/uterminal/infrastructure/updatepackage.cpp)
target_include_directories(UTerminalUpdateRunner PRIVATE src/uterminal)
target_link_libraries(UTerminalUpdateRunner PRIVATE Qt6::Core)
add_library(UTerminalShell SHARED src/uterminal/shell_extension.cpp src/uterminal/shell_extension.def)
foreach(ut_target UTerminal UTerminalUpdateRunner UTerminalShell)
  target_sources(${ut_target} PRIVATE ${CMAKE_CURRENT_BINARY_DIR}/uterminal-version.rc)
endforeach()
target_link_libraries(UTerminalShell PRIVATE ole32 shell32 shlwapi uuid)
target_compile_options(UTerminalShell PRIVATE $<$<CXX_COMPILER_ID:MSVC>:/EHsc>)
set_property(TARGET UTerminalShell PROPERTY MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
add_dependencies(UTerminal UTerminalShell)
add_dependencies(UTerminal UTerminalUpdateRunner)
target_link_libraries(UTerminal PRIVATE uterminal_terminal Qt6::Widgets Qt6::QuickControls2)
target_compile_definitions(UTerminal PRIVATE $<$<CONFIG:Debug>:UTERMINAL_SOURCE_RESOURCES="${CMAKE_CURRENT_SOURCE_DIR}/resources">)
set_target_properties(UTerminal PROPERTIES VS_DEBUGGER_ENVIRONMENT "PATH=$<TARGET_FILE_DIR:Qt6::Core>;%PATH%\nQT_PLUGIN_PATH=$<TARGET_FILE_DIR:Qt6::Core>/../plugins\nQML_IMPORT_PATH=$<TARGET_FILE_DIR:Qt6::Core>/../qml")
add_custom_target(uterminal_resources ALL
  COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_CURRENT_SOURCE_DIR}/resources" "${CMAKE_CURRENT_BINARY_DIR}/$<CONFIG>/resources")
add_dependencies(UTerminal uterminal_resources)
install(TARGETS UTerminal UTerminalUpdateRunner UTerminalShell RUNTIME DESTINATION .)
install(DIRECTORY resources/ DESTINATION resources)
include(CTest)
if(BUILD_TESTING)
  add_executable(uterminal_terminal_benchmark tests/cpp/terminal_benchmark.cpp)
  target_link_libraries(uterminal_terminal_benchmark PRIVATE uterminal_terminal)
  add_executable(uterminal_render_benchmark tests/cpp/render_benchmark.cpp)
  target_link_libraries(uterminal_render_benchmark PRIVATE uterminal_terminal psapi)
  add_test(NAME archive-validation COMMAND "$ENV{SystemRoot}/System32/WindowsPowerShell/v1.0/powershell.exe"
    -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "${CMAKE_CURRENT_SOURCE_DIR}/scripts/test-uterminal-archive.ps1"
    -OutputRoot "${CMAKE_CURRENT_BINARY_DIR}/archive-validation")
  set_tests_properties(archive-validation PROPERTIES TIMEOUT 30)
  add_executable(uterminal_update_fixture WIN32 tests/cpp/update_installer_fixture.cpp)
  target_link_libraries(uterminal_update_fixture PRIVATE Qt6::Core)
  qt6_generate_moc(tests/cpp/core_tests.cpp ${CMAKE_CURRENT_BINARY_DIR}/core_tests.moc)
  add_executable(uterminal_core_tests tests/cpp/core_tests.cpp ${CMAKE_CURRENT_BINARY_DIR}/core_tests.moc)
  target_include_directories(uterminal_core_tests PRIVATE ${CMAKE_CURRENT_BINARY_DIR})
  target_link_libraries(uterminal_core_tests PRIVATE uterminal_core Qt6::Test)
  add_test(NAME core COMMAND uterminal_core_tests -o ${CMAKE_CURRENT_BINARY_DIR}/core-results.txt,txt)
  set_tests_properties(core PROPERTIES ENVIRONMENT_MODIFICATION "PATH=path_list_prepend:$<TARGET_FILE_DIR:Qt6::Core>")
  qt6_generate_moc(tests/cpp/runtime_tests.cpp ${CMAKE_CURRENT_BINARY_DIR}/runtime_tests.moc)
  add_executable(uterminal_runtime_tests tests/cpp/runtime_tests.cpp ${CMAKE_CURRENT_BINARY_DIR}/runtime_tests.moc)
  target_include_directories(uterminal_runtime_tests PRIVATE ${CMAKE_CURRENT_BINARY_DIR})
  target_link_libraries(uterminal_runtime_tests PRIVATE uterminal_terminal Qt6::Test)
  add_dependencies(uterminal_runtime_tests UTerminalUpdateRunner uterminal_update_fixture)
  add_test(NAME runtime COMMAND uterminal_runtime_tests -o ${CMAKE_CURRENT_BINARY_DIR}/runtime-results.txt,txt)
  set_tests_properties(runtime PROPERTIES TIMEOUT 45)
  set_tests_properties(runtime PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen;QT_PLUGIN_PATH=$<TARGET_FILE_DIR:Qt6::Core>/../plugins" ENVIRONMENT_MODIFICATION "PATH=path_list_prepend:$<TARGET_FILE_DIR:Qt6::Core>")
  qt6_generate_moc(tests/cpp/plugin_integration_tests.cpp ${CMAKE_CURRENT_BINARY_DIR}/plugin_integration_tests.moc)
  add_executable(uterminal_plugin_integration_tests tests/cpp/plugin_integration_tests.cpp ${CMAKE_CURRENT_BINARY_DIR}/plugin_integration_tests.moc)
  target_include_directories(uterminal_plugin_integration_tests PRIVATE ${CMAKE_CURRENT_BINARY_DIR})
  target_link_libraries(uterminal_plugin_integration_tests PRIVATE uterminal_terminal Qt6::Test)
  # Network integration is explicitly invoked with an isolated data directory.
endif()
