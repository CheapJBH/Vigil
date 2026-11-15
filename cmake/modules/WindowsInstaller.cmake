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
	COMMAND rm -rf ${WINDOWS_INSTALL_FILES}*
	COMMAND mkdir -p ${WINDOWS_INSTALL_FILES}/interception
	COMMAND cp ${CMAKE_SOURCE_DIR}/3rdparty/interception/* ${WINDOWS_INSTALL_FILES}/interception
	COMMAND cp ${CMAKE_SOURCE_DIR}/3rdparty/ddengine/${DLL_DDENGINE} ${WINDOWS_INSTALL_FILES}
	COMMAND cp core/vigil-core.dll ${WINDOWS_INSTALL_FILES}
	COMMAND find . -mindepth 2 -name 'vigil-*.exe' -exec cp '{}' ${WINDOWS_INSTALL_FILES}/ '\;'
	COMMAND mkdir -p ${WINDOWS_INSTALL_FILES}/plugins
	COMMAND find plugins/ -name '*.dll' -exec cp '{}' ${WINDOWS_INSTALL_FILES}/plugins/ '\;'
	COMMAND mv ${WINDOWS_INSTALL_FILES}/plugins/lib*.dll ${WINDOWS_INSTALL_FILES}
	COMMAND mv ${WINDOWS_INSTALL_FILES}/plugins/vnchooks.dll ${WINDOWS_INSTALL_FILES}
	COMMAND mkdir -p ${WINDOWS_INSTALL_FILES}/translations
	COMMAND cp translations/*qm ${WINDOWS_INSTALL_FILES}/translations/
	COMMAND bash -c "cp ${DLLDIR}/libjpeg-*.dll ${WINDOWS_INSTALL_FILES} 2>/dev/null || true"
	COMMAND bash -c "cp ${DLLDIR}/libpng16-*.dll ${WINDOWS_INSTALL_FILES} 2>/dev/null || true"
	COMMAND bash -c "cp ${DLLDIR}/libcrypto-3*.dll ${DLLDIR}/libssl-3*.dll ${WINDOWS_INSTALL_FILES} 2>/dev/null || true"
	COMMAND bash -c "cp ${DLLDIR}/libqca-qt6.dll ${WINDOWS_INSTALL_FILES} 2>/dev/null || true"
	COMMAND bash -c "cp ${DLLDIR}/libsasl2-*.dll ${WINDOWS_INSTALL_FILES} 2>/dev/null || true"
	COMMAND bash -c "cp ${DLLDIR}/libldap*.dll ${DLLDIR}/liblber*.dll ${WINDOWS_INSTALL_FILES} 2>/dev/null || true"
	COMMAND bash -c "cp ${DLLDIR}/interception.dll ${WINDOWS_INSTALL_FILES} 2>/dev/null || true"
	COMMAND bash -c "cp ${DLLDIR}/liblzo2-*.dll ${WINDOWS_INSTALL_FILES} 2>/dev/null || true"
	COMMAND bash -c "cp ${DLLDIR}/libvncclient.dll ${DLLDIR}/libvncserver.dll ${WINDOWS_INSTALL_FILES} 2>/dev/null || true"
	COMMAND bash -c "cp ${DLLDIR_LIB}/zlib1.dll ${WINDOWS_INSTALL_FILES} 2>/dev/null || true"
	COMMAND bash -c "cp ${DLLDIR_LIB}/libwinpthread-1.dll ${WINDOWS_INSTALL_FILES} 2>/dev/null || true"
	COMMAND bash -c "cp ${DLLDIR_GCC}/libstdc++-6.dll ${WINDOWS_INSTALL_FILES} 2>/dev/null || true"
	COMMAND bash -c "cp ${DLLDIR_GCC}/libssp-0.dll ${WINDOWS_INSTALL_FILES} 2>/dev/null || true"
	COMMAND bash -c "cp ${DLLDIR_GCC}/${DLL_GCC} ${WINDOWS_INSTALL_FILES} 2>/dev/null || true"
	COMMAND mkdir -p ${WINDOWS_INSTALL_FILES}/crypto
	COMMAND bash -c "cp ${DLLDIR_LIB}/qca-qt6/crypto/libqca-ossl.dll ${WINDOWS_INSTALL_FILES}/crypto 2>/dev/null || true"
	COMMAND cp ${DLLDIR}/Qt6Core.dll
				${DLLDIR}/Qt6Core5Compat.dll
				${DLLDIR}/Qt6Gui.dll
				${DLLDIR}/Qt6Widgets.dll
				${DLLDIR}/Qt6Network.dll
				${DLLDIR}/Qt6Concurrent.dll
				${DLLDIR}/Qt6HttpServer.dll
				${DLLDIR}/Qt6WebSockets.dll
			${WINDOWS_INSTALL_FILES}
	COMMAND mkdir -p ${WINDOWS_INSTALL_FILES}/imageformats
	COMMAND cp ${QT_PLUGIN_DIR}/imageformats/qjpeg.dll ${WINDOWS_INSTALL_FILES}/imageformats
	COMMAND mkdir -p ${WINDOWS_INSTALL_FILES}/platforms
	COMMAND cp ${QT_PLUGIN_DIR}/platforms/qwindows.dll ${WINDOWS_INSTALL_FILES}/platforms
	COMMAND mkdir -p ${WINDOWS_INSTALL_FILES}/styles
	COMMAND cp ${QT_PLUGIN_DIR}/styles/*.dll ${WINDOWS_INSTALL_FILES}/styles
	COMMAND mkdir -p ${WINDOWS_INSTALL_FILES}/tls
	COMMAND cp ${QT_PLUGIN_DIR}/tls/qopensslbackend.dll ${WINDOWS_INSTALL_FILES}/tls
	COMMAND bash -c "${MINGW_TOOL_PREFIX}strip ${WINDOWS_INSTALL_FILES}/*.dll ${WINDOWS_INSTALL_FILES}/*.exe ${WINDOWS_INSTALL_FILES}/plugins/*.dll ${WINDOWS_INSTALL_FILES}/platforms/*.dll ${WINDOWS_INSTALL_FILES}/styles/*.dll ${WINDOWS_INSTALL_FILES}/crypto/*.dll 2>/dev/null || true"
	COMMAND cp ${CMAKE_SOURCE_DIR}/COPYING ${WINDOWS_INSTALL_FILES}
	COMMAND cp ${CMAKE_SOURCE_DIR}/COPYING ${WINDOWS_INSTALL_FILES}/LICENSE.TXT
	COMMAND cp ${CMAKE_SOURCE_DIR}/README.md ${WINDOWS_INSTALL_FILES}/README.TXT
	COMMAND cp -ra ${CMAKE_SOURCE_DIR}/nsis ${WINDOWS_INSTALL_FILES}
	COMMAND cp -ra ${CMAKE_SOURCE_DIR}/tools/classroom-setup/teacher ${WINDOWS_INSTALL_FILES}/classroom-teacher
	COMMAND cp -ra ${CMAKE_SOURCE_DIR}/tools/classroom-setup/student ${WINDOWS_INSTALL_FILES}/classroom-student
	COMMAND cp ${CMAKE_BINARY_DIR}/nsis/vigil.nsi ${WINDOWS_INSTALL_FILES}
	COMMAND find ${WINDOWS_INSTALL_FILES} -ls
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

