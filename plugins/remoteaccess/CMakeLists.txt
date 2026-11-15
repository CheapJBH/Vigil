include(BuildVigilPlugin)

build_vigil_plugin(remoteaccess
	NAME RemoteAccess
	SOURCES
	RemoteAccessFeaturePlugin.h
	RemoteAccessFeaturePlugin.cpp
	RemoteAccessWidget.h
	RemoteAccessWidget.cpp
	remoteaccess.qrc)
