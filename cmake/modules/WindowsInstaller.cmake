set(WINDOWS_INSTALL_FILES "vigil-${VIGIL_WINDOWS_ARCH}-${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}.${VERSION_BUILD}")

# 交叉编译（Arch/MinGW）与原生 MSYS2 构建的路径差异
if(NOT DEFINED MINGW_PREFIX OR MINGW_PREFIX STREQUAL "")
	set(MINGW_PREFIX "/mingw64")
endif()
if(NOT DEFINED MINGW_TARGET OR MINGW_TARGET STREQUAL "")
	set(MINGW_TARGET "x86_64-w64-mingw32")
endif()
if(NOT DEFINED MINGW_TOOL_PREFIX)
	set(MINGW_TOOL_PREFIX "")
endif()

# Qt 插件目录与 GCC 运行时目录必须由 bash 侧探测：
# CMake 在 Windows 上把 "/mingw64/..." 当成当前盘根目录（C:/mingw64），
# 导致 EXISTS()/file(GLOB) 全部判假，切勿在此处做路径存在性判断。
set(QT_PLUGIN_DIR "")
set(DLLDIR_GCC "")

if(VIGIL_BUILD_WIN64)
	set(DLL_GCC "libgcc_s_seh-1.dll")
	set(DLL_DDENGINE "ddengine64.dll")
else()
	set(DLL_GCC "libgcc_s_dw2-1.dll")
	set(DLL_DDENGINE "ddengine.dll")
endif()

add_custom_target(windows-binaries
	COMMAND ${CMAKE_COMMAND} --build ${CMAKE_BINARY_DIR}
	COMMAND ${CMAKE_COMMAND} -E env
		STAGING=${WINDOWS_INSTALL_FILES}
		SRCDIR=${CMAKE_SOURCE_DIR}
		BUILDDIR=${CMAKE_BINARY_DIR}
		MINGW_PREFIX=${MINGW_PREFIX}
		DLLDIR_GCC=${DLLDIR_GCC}
		DLL_GCC=${DLL_GCC}
		DLL_DDENGINE=${DLL_DDENGINE}
		QT_PLUGIN_DIR=${QT_PLUGIN_DIR}
		STRIP=${MINGW_TOOL_PREFIX}strip
		bash ${CMAKE_SOURCE_DIR}/cmake/scripts/stage-windows.sh
)

add_custom_target(create-windows-installer
	COMMAND makensis ${WINDOWS_INSTALL_FILES}/vigil.nsi
	COMMAND mv ${WINDOWS_INSTALL_FILES}/vigil-*setup.exe .
	COMMAND rm -rf ${WINDOWS_INSTALL_FILES}
	DEPENDS windows-binaries
)

add_custom_target(prepare-dev-nsi
	COMMAND sed -i ${WINDOWS_INSTALL_FILES}/vigil.nsi -e "s,/SOLID lzma,zlib,g"
	DEPENDS windows-binaries)

add_custom_target(dev-nsi
	DEPENDS prepare-dev-nsi create-windows-installer
)

