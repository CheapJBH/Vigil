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

# Qt 插件目录：MSYS2 在 share/qt6/plugins，Arch 交叉环境在 <prefix>/plugins
if(EXISTS "${MINGW_PREFIX}/share/qt6/plugins")
	set(QT_PLUGIN_DIR "${MINGW_PREFIX}/share/qt6/plugins")
else()
	set(QT_PLUGIN_DIR "${MINGW_PREFIX}/plugins")
endif()

set(DLLDIR "${MINGW_PREFIX}/bin")
set(DLLDIR_LIB "${MINGW_PREFIX}/lib")
string(REGEX MATCH "^[^.]+" GCC_VERSION_MAJOR ${CMAKE_CXX_COMPILER_VERSION})

# GCC 运行时目录：MSYS2 无 -posix 后缀，因此直接探测
set(DLLDIR_GCC "/usr/lib/gcc/${MINGW_TARGET}/${GCC_VERSION_MAJOR}-posix")
if(NOT EXISTS "${DLLDIR_GCC}")
	file(GLOB _gcc_runtime_dirs "${MINGW_PREFIX}/lib/gcc/${MINGW_TARGET}/*")
	list(SORT _gcc_runtime_dirs)
	if(_gcc_runtime_dirs)
		list(GET _gcc_runtime_dirs 0 DLLDIR_GCC)
	endif()
endif()

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

