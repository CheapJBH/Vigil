# BuildVigilPlugin.cmake - Copyright (c) 2017-2026 Tobias Junghans
#
# description: build Vigil plugin
# usage: build_vigil_plugin(<NAME> <SOURCES>)

include(SetDefaultTargetProperties)
include(WindowsBuildHelpers)

function(build_vigil_plugin TARGET)
	cmake_parse_arguments(PARSE_ARGV 1 arg
		""
		""
		"SOURCES")

	set(LIBRARY_TYPE "MODULE")
	if(WITH_TESTS)
		set(LIBRARY_TYPE "SHARED")
	endif()
	add_library(${TARGET} ${LIBRARY_TYPE} ${arg_SOURCES})

	target_include_directories(${TARGET} PRIVATE ${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_CURRENT_SOURCE_DIR})
	target_link_libraries(${TARGET} PRIVATE vigil-core)

	set_default_target_properties(${TARGET})
	set_target_properties(${TARGET} PROPERTIES PREFIX "")
	if(${TARGET}_COMPONENT)
		install(TARGETS ${TARGET} COMPONENT ${${TARGET}_COMPONENT} LIBRARY DESTINATION ${VIGIL_INSTALL_PLUGIN_DIR})
	else()
		install(TARGETS ${TARGET} LIBRARY DESTINATION ${VIGIL_INSTALL_PLUGIN_DIR})
	endif()
	if(WITH_PCH)
		target_precompile_headers(${TARGET} REUSE_FROM vigil-library-pch)
	endif()
	if (VIGIL_BUILD_WINDOWS)
		add_windows_resources(${TARGET} ${ARGN})
	endif()
endfunction()

macro(test_vigil_plugin TARGET TEST_NAME)
	if(WITH_TESTS)
		add_executable(${TEST_NAME} ${TEST_NAME}.cpp)
		add_test(NAME ${TEST_NAME} COMMAND ${TEST_NAME})
		target_link_libraries(${TEST_NAME} PRIVATE vigil-core ${TARGET})
	endif()
endmacro()
