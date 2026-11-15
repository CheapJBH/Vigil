include(BuildVigilPlugin)

build_vigil_plugin(usersessioncontrol
	NAME UserSessionControl
	SOURCES
	UserSessionControlPlugin.cpp
	UserSessionControlPlugin.h
	UserLoginDialog.cpp
	UserLoginDialog.h
	UserLoginDialog.ui
	usersessioncontrol.qrc
	)
