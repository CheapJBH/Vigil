include(BuildVigilApplication)

build_vigil_application(vigil-service
	NAME Service
	SOURCES
	src/main.cpp)

if(VIGIL_BUILD_LINUX)
	configure_file(${CMAKE_CURRENT_SOURCE_DIR}/vigil.service.in ${CMAKE_CURRENT_BINARY_DIR}/vigil.service @ONLY)
	if(NOT SYSTEMD_SERVICE_INSTALL_DIR)
		set(SYSTEMD_SERVICE_INSTALL_DIR /lib/systemd/system)
	endif()
	install(FILES ${CMAKE_CURRENT_BINARY_DIR}/vigil.service DESTINATION ${SYSTEMD_SERVICE_INSTALL_DIR})
endif()
