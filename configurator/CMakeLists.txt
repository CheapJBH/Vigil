include(BuildVigilApplication)

build_vigil_application(vigil-configurator
	NAME Configurator
	WINDOWS_ICON "data/vigil-configurator.ico"
	REQUIRE_ADMINISTRATOR_PRIVILEGES
	SOURCES
	src/AccessControlPage.cpp
	src/AccessControlPage.h
	src/AccessControlPage.ui
	src/AccessControlRuleEditDialog.cpp
	src/AccessControlRuleEditDialog.h
	src/AccessControlRuleEditDialog.ui
	src/AccessControlRuleListModel.cpp
	src/AccessControlRuleListModel.h
	src/AccessControlRulesTestDialog.cpp
	src/AccessControlRulesTestDialog.h
	src/AccessControlRulesTestDialog.ui
	src/GeneralConfigurationPage.cpp
	src/GeneralConfigurationPage.h
	src/GeneralConfigurationPage.ui
	src/main.cpp
	src/MainWindow.cpp
	src/MainWindow.h
	src/MainWindow.ui
	src/MasterConfigurationPage.cpp
	src/MasterConfigurationPage.h
	src/MasterConfigurationPage.ui
	src/ServiceConfigurationPage.cpp
	src/ServiceConfigurationPage.h
	src/ServiceConfigurationPage.ui
	resources/configurator.qrc)

if(VIGIL_BUILD_LINUX)
	xdg_install(${CMAKE_CURRENT_BINARY_DIR}/data/vigil-configurator.desktop ${CMAKE_CURRENT_SOURCE_DIR}/data/vigil-configurator.xpm ${CMAKE_CURRENT_SOURCE_DIR}/data/vigil-configurator.png ${CMAKE_CURRENT_SOURCE_DIR}/data/vigil-configurator.svg)
	install(FILES ${CMAKE_CURRENT_BINARY_DIR}/data/io.vigil.vigil-configurator.policy DESTINATION ${CMAKE_INSTALL_PREFIX}/share/polkit-1/actions)
endif()
