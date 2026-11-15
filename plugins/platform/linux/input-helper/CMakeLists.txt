add_executable(vigil-input-helper input-block-helper.c)

set_default_target_properties(vigil-input-helper)

set_target_properties(vigil-input-helper PROPERTIES
	C_STANDARD 11
	C_STANDARD_REQUIRED ON
)

install(TARGETS vigil-input-helper RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
	PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE SETUID
	GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)
