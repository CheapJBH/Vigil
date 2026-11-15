include(BuildVigilPlugin)

build_vigil_plugin(external-vnc-server
	NAME ExternalVncServer
	SOURCES
	ExternalVncServer.cpp
	ExternalVncServerConfigurationWidget.cpp
	ExternalVncServerConfigurationWidget.ui
	ExternalVncServer.h
	ExternalVncServerConfiguration.h
	ExternalVncServerConfigurationWidget.h
	)
