include(BuildVigilPlugin)

build_vigil_plugin(powercontrol
	NAME PowerControl
	SOURCES
	PowerControlFeaturePlugin.cpp
	PowerControlFeaturePlugin.h
	PowerDownTimeInputDialog.cpp
	PowerDownTimeInputDialog.h
	PowerDownTimeInputDialog.ui
	powercontrol.qrc
	)
