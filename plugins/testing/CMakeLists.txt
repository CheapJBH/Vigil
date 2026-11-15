include(BuildVigilPlugin)

if(VIGIL_DEBUG)
	build_vigil_plugin(testing TestingCommandLinePlugin.cpp TestingCommandLinePlugin.h)
endif()
