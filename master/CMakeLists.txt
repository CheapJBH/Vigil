include(BuildVigilApplication)

file(GLOB master_SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/src/*.*)

set(master_RESOURCES ${CMAKE_CURRENT_SOURCE_DIR}/resources/master.qrc)
if(VIGIL_DEBUG)
	set(master_RESOURCES ${master_RESOURCES} ${CMAKE_CURRENT_SOURCE_DIR}/resources/examples.qrc)
endif()

build_vigil_application(vigil-master
	NAME Master
	WINDOWS_ICON data/vigil-master.ico
	SOURCES
	${master_SOURCES}
	${master_RESOURCES})

if(VIGIL_BUILD_LINUX)
	xdg_install(${CMAKE_CURRENT_BINARY_DIR}/data/vigil-master.desktop ${CMAKE_CURRENT_SOURCE_DIR}/data/vigil-master.xpm ${CMAKE_CURRENT_SOURCE_DIR}/data/vigil-master.png ${CMAKE_CURRENT_SOURCE_DIR}/data/vigil-master.svg)
endif()
