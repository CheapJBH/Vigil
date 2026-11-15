#!/usr/bin/env bash
# stage-windows.sh - 收集 Windows 构建产物到发布目录
#
# 由 cmake/modules/WindowsInstaller.cmake 的 windows-binaries 目标调用。
# 统一在 bash 下执行，避免 CMake 在 Windows 上用 cmd.exe 解析 * 与 \; 时出错。
#
# 环境变量：
#   STAGING        发布目录名（相对构建目录）
#   SRCDIR         源码目录
#   BUILDDIR       构建目录
#   MINGW_PREFIX   MinGW 前缀（如 /mingw64）
#   DLLDIR_GCC     GCC 运行时 DLL 目录
#   DLL_GCC        GCC 运行时 DLL 文件名
#   DLL_DDENGINE   ddengine DLL 文件名
#   QT_PLUGIN_DIR  Qt 插件目录
#   STRIP          strip 命令（可为空）

set -uo pipefail

: "${STAGING:?}" "${SRCDIR:?}" "${BUILDDIR:?}" "${MINGW_PREFIX:?}"
: "${DLLDIR_GCC:?}" "${DLL_GCC:?}" "${DLL_DDENGINE:?}" "${QT_PLUGIN_DIR:?}"
STRIP="${STRIP:-}"

cd "$BUILDDIR"

echo "== staging into $STAGING"

rm -rf "$STAGING"
mkdir -p "$STAGING"

# interception 驱动安装器（不含库源码）
mkdir -p "$STAGING/interception"
cp "$SRCDIR"/3rdparty/interception/install-interception.exe "$STAGING/interception/" 2>/dev/null || true
cp "$SRCDIR"/3rdparty/interception/*.bat "$STAGING/interception/" 2>/dev/null || true

cp "$SRCDIR/3rdparty/ddengine/$DLL_DDENGINE" "$STAGING/" 2>/dev/null || true
cp core/vigil-core.dll "$STAGING/" 2>/dev/null || true

# 所有可执行文件
find . -mindepth 2 -name 'vigil-*.exe' -exec cp {} "$STAGING/" \; 2>/dev/null || true

# 插件
mkdir -p "$STAGING/plugins"
find plugins/ -name '*.dll' -exec cp {} "$STAGING/plugins/" \; 2>/dev/null || true
for f in "$STAGING"/plugins/lib*.dll; do
	[ -e "$f" ] && mv "$f" "$STAGING/"
done
[ -f "$STAGING/plugins/vnchooks.dll" ] && mv "$STAGING/plugins/vnchooks.dll" "$STAGING/"

# 翻译
mkdir -p "$STAGING/translations"
cp translations/*.qm "$STAGING/translations/" 2>/dev/null || true

copy_if_present() {
	for src in "$@"; do
		[ -e "$src" ] && cp "$src" "$STAGING/" 2>/dev/null
	done
	return 0
}

# 第三方运行时 DLL（版本号随发行版变化，统一用通配）
copy_if_present "$MINGW_PREFIX"/bin/libjpeg-*.dll
copy_if_present "$MINGW_PREFIX"/bin/libpng16-*.dll
copy_if_present "$MINGW_PREFIX"/bin/libpng-*.dll
copy_if_present "$MINGW_PREFIX"/bin/libcrypto-*.dll "$MINGW_PREFIX"/bin/libssl-*.dll
copy_if_present "$MINGW_PREFIX"/bin/libqca-qt6.dll
copy_if_present "$MINGW_PREFIX"/bin/libsasl2-*.dll
copy_if_present "$MINGW_PREFIX"/bin/libldap*.dll "$MINGW_PREFIX"/bin/liblber*.dll
copy_if_present "$MINGW_PREFIX"/bin/liblzo2-*.dll
copy_if_present "$MINGW_PREFIX"/bin/libvncclient.dll "$MINGW_PREFIX"/bin/libvncserver.dll
copy_if_present "$MINGW_PREFIX"/bin/zlib1.dll "$MINGW_PREFIX"/lib/zlib1.dll
copy_if_present "$MINGW_PREFIX"/bin/libwinpthread-1.dll "$MINGW_PREFIX"/lib/libwinpthread-1.dll
copy_if_present "$MINGW_PREFIX"/bin/libssp-*.dll "$MINGW_PREFIX"/lib/libssp-*.dll
copy_if_present "$DLLDIR_GCC/$DLL_GCC"
copy_if_present "$DLLDIR_GCC/libstdc++-6.dll"
copy_if_present "$DLLDIR_GCC/libgcc_s_seh-1.dll"

# QCA 加密插件
mkdir -p "$STAGING/crypto"
copy_if_present "$MINGW_PREFIX"/lib/qca-qt6/crypto/libqca-ossl.dll
mv "$STAGING"/libqca-ossl.dll "$STAGING/crypto/" 2>/dev/null || true

# Qt 运行库
copy_if_present \
	"$MINGW_PREFIX/bin/Qt6Core.dll" \
	"$MINGW_PREFIX/bin/Qt6Core5Compat.dll" \
	"$MINGW_PREFIX/bin/Qt6Gui.dll" \
	"$MINGW_PREFIX/bin/Qt6Widgets.dll" \
	"$MINGW_PREFIX/bin/Qt6Network.dll" \
	"$MINGW_PREFIX/bin/Qt6Concurrent.dll" \
	"$MINGW_PREFIX/bin/Qt6HttpServer.dll" \
	"$MINGW_PREFIX/bin/Qt6WebSockets.dll"

# Qt 插件
mkdir -p "$STAGING/imageformats" "$STAGING/platforms" "$STAGING/styles" "$STAGING/tls"
cp "$QT_PLUGIN_DIR"/imageformats/qjpeg.dll "$STAGING/imageformats/" 2>/dev/null || true
cp "$QT_PLUGIN_DIR"/platforms/qwindows.dll "$STAGING/platforms/" 2>/dev/null || true
cp "$QT_PLUGIN_DIR"/styles/*.dll "$STAGING/styles/" 2>/dev/null || true
cp "$QT_PLUGIN_DIR"/tls/qopensslbackend.dll "$STAGING/tls/" 2>/dev/null || true

# 瘦身（失败不影响产物）
if [ -n "$STRIP" ]; then
	"$STRIP" "$STAGING"/*.dll "$STAGING"/*.exe \
		"$STAGING"/plugins/*.dll "$STAGING"/platforms/*.dll \
		"$STAGING"/styles/*.dll "$STAGING"/crypto/*.dll 2>/dev/null || true
fi

cp "$SRCDIR/COPYING" "$STAGING/" 2>/dev/null || true
cp "$SRCDIR/COPYING" "$STAGING/LICENSE.TXT" 2>/dev/null || true
cp "$SRCDIR/README.md" "$STAGING/README.TXT" 2>/dev/null || true

cp -ra "$SRCDIR/nsis" "$STAGING/" 2>/dev/null || true
cp -ra "$SRCDIR/tools/classroom-setup/teacher" "$STAGING/classroom-teacher" 2>/dev/null || true
cp -ra "$SRCDIR/tools/classroom-setup/student" "$STAGING/classroom-student" 2>/dev/null || true
cp "$BUILDDIR/nsis/vigil.nsi" "$STAGING/" 2>/dev/null || true

echo "== staged files: $(find "$STAGING" -type f | wc -l)"
find "$STAGING" -maxdepth 1 -ls
