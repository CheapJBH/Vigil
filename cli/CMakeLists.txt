include(BuildVigilApplication)

set(cli_SOURCES
	src/main.cpp
	src/ConfigCommands.cpp
	src/ConfigCommands.h
	src/FeatureCommands.cpp
	src/FeatureCommands.h
	src/PluginCommands.cpp
	src/PluginCommands.h
	src/ServiceControlCommands.cpp
	src/ServiceControlCommands.h
	src/ShellCommands.cpp
	src/ShellCommands.h
	)

build_vigil_application(vigil-cli
	NAME CLI
	DESCRIPTION "Vigil Command Line Interface (console version)"
	CONSOLE
	SOURCES ${cli_SOURCES})

target_compile_options(vigil-cli PRIVATE -Wno-date-time)

if(VIGIL_BUILD_WINDOWS)
	build_vigil_application(vigil-wcli
		NAME WCLI
		DESCRIPTION "Vigil Command Line Interface (non-console version)"
		SOURCES ${cli_SOURCES})
endif()
