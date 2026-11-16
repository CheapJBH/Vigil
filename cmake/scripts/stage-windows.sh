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
#   DLL_GCC        GCC 运行时 DLL 文件名
#   DLL_DDENGINE   ddengine DLL 文件名
#   STRIP          strip 命令（可为空）
#
# 注意：Qt 插件目录 / GCC 运行时目录一律在这里探测。
# CMake 在 Windows 上把 "/mingw64/..." 解析成当前盘根目录（C:/mingw64），
# 任何 EXISTS()/file(GLOB) 判断都会得到错误结果。

set -uo pipefail

: "${STAGING:?}" "${SRCDIR:?}" "${BUILDDIR:?}" "${MINGW_PREFIX:?}"
: "${DLL_GCC:?}" "${DLL_DDENGINE:?}"
STRIP="${STRIP:-}"
QT_PLUGIN_DIR="${QT_PLUGIN_DIR:-}"
DLLDIR_GCC="${DLLDIR_GCC:-}"

MISSING=()

note_missing() { MISSING+=("$1"); }

# CMake 在 Windows 上给出的是 D:/... 形式，MSYS2 的 bash 不一定认，
# 统一转成 POSIX 路径后再切换目录。
if command -v cygpath >/dev/null 2>&1; then
	BUILDDIR=$(cygpath -u "$BUILDDIR")
	SRCDIR=$(cygpath -u "$SRCDIR")
fi

cd "$BUILDDIR" || { echo "FATAL: cannot cd to $BUILDDIR"; exit 1; }

echo "== pwd=$(pwd)"
echo "== staging into $STAGING"

# ---- 路径探测（必须在 bash 里做）----------------------------------------
if [ -z "$QT_PLUGIN_DIR" ] || [ ! -d "$QT_PLUGIN_DIR" ]; then
	QT_PLUGIN_DIR=""
	for cand in \
		"$MINGW_PREFIX/share/qt6/plugins" \
		"$MINGW_PREFIX/lib/qt6/plugins" \
		"$MINGW_PREFIX/plugins"
	do
		if [ -d "$cand" ]; then QT_PLUGIN_DIR="$cand"; break; fi
	done
	if [ -z "$QT_PLUGIN_DIR" ] && command -v qtpaths6 >/dev/null 2>&1; then
		QT_PLUGIN_DIR=$(qtpaths6 --query QT_INSTALL_PLUGINS 2>/dev/null || true)
	fi
fi
echo "== QT_PLUGIN_DIR=$QT_PLUGIN_DIR"

if [ -z "$DLLDIR_GCC" ] || [ ! -d "$DLLDIR_GCC" ]; then
	DLLDIR_GCC=""
	for cand in \
		"$MINGW_PREFIX/lib/gcc/x86_64-w64-mingw32"/* \
		"$MINGW_PREFIX"/lib/gcc/*/*
	do
		if [ -d "$cand" ] && [ -f "$cand/libstdc++-6.dll" ]; then
			DLLDIR_GCC="$cand"; break
		fi
		if [ -d "$cand" ] && compgen -G "$cand/libstdc++*.dll" >/dev/null; then
			DLLDIR_GCC="$cand"; break
		fi
	done
fi
echo "== DLLDIR_GCC=$DLLDIR_GCC"

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

# 仓库里的 .ts 直接用 lrelease 编译，不依赖 lupdate（CI 上 lupdate 会因缺 DLL 崩溃）
LREL=$(command -v lrelease6 2>/dev/null || command -v lrelease 2>/dev/null || true)
if [ -n "$LREL" ]; then
	ok=0
	for ts in "$SRCDIR"/translations/*.ts; do
		[ -e "$ts" ] || continue
		base=$(basename "$ts" .ts)
		if "$LREL" "$ts" -qm "$STAGING/translations/$base.qm" >/dev/null 2>&1; then
			ok=$((ok + 1))
		else
			echo "!! lrelease failed: $ts"
		fi
	done
	echo "== translations compiled: $ok"
else
	echo "!! lrelease not found, skipping program translations"
fi

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

# GCC 运行时（缺了程序无法启动）
if [ -n "$DLLDIR_GCC" ] && [ -d "$DLLDIR_GCC" ]; then
	for f in "$DLLDIR_GCC"/libstdc++*.dll "$DLLDIR_GCC"/libgcc_s*.dll; do
		[ -e "$f" ] && cp "$f" "$STAGING/"
	done
fi
copy_if_present "$MINGW_PREFIX"/bin/libstdc++-6.dll "$MINGW_PREFIX"/bin/libgcc_s_seh-1.dll

# QCA 加密插件（没有它 KeyFile / RSA 认证不可用）
mkdir -p "$STAGING/crypto"
for cand in \
	"$MINGW_PREFIX/lib/qca-qt6/crypto/libqca-ossl.dll" \
	"$MINGW_PREFIX/lib/qca-qt6/libqca-ossl.dll" \
	"$MINGW_PREFIX/lib/qca/crypto/libqca-ossl.dll" \
	"$MINGW_PREFIX/plugins/crypto/libqca-ossl.dll" \
	"$MINGW_PREFIX/lib/qca-qt6/crypto/libqca-ossl-qt6.dll" \
	"$MINGW_PREFIX/bin/libqca-ossl.dll"
do
	[ -e "$cand" ] && cp "$cand" "$STAGING/crypto/" && break
done
if [ ! -e "$STAGING/crypto/libqca-ossl.dll" ]; then
	# 路径随 QCA 版本变化，最后全盘兜底
	ossl=$(find "$MINGW_PREFIX" -iname '*qca*ossl*.dll' 2>/dev/null | head -1)
	if [ -n "$ossl" ]; then
		cp "$ossl" "$STAGING/crypto/libqca-ossl.dll"
	else
		echo "!! qca-ossl plugin not found; dumping QCA layout for diagnosis" >&2
		find "$MINGW_PREFIX" -iname '*qca*' -maxdepth 6 2>/dev/null | head -40 >&2
	fi
fi
[ -e "$STAGING/libqca-ossl.dll" ] && mv "$STAGING/libqca-ossl.dll" "$STAGING/crypto/"

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

# Qt 插件：整目录复制，避免遗漏后端（qwindows / qjpeg / 样式 / TLS）
if [ -n "$QT_PLUGIN_DIR" ] && [ -d "$QT_PLUGIN_DIR" ]; then
	for sub in platforms imageformats styles tls iconengines networkinformation platformthemes; do
		if [ -d "$QT_PLUGIN_DIR/$sub" ]; then
			mkdir -p "$STAGING/$sub"
			cp "$QT_PLUGIN_DIR/$sub"/*.dll "$STAGING/$sub/" 2>/dev/null
		fi
	done
fi
if [ ! -f "$STAGING/platforms/qwindows.dll" ]; then
	# 兜底：MSYS2 不同版本路径略有差异
	qw=$(find "$MINGW_PREFIX" -name qwindows.dll -path '*platforms*' 2>/dev/null | head -1)
	if [ -n "$qw" ]; then
		mkdir -p "$STAGING/platforms"
		cp "$qw" "$STAGING/platforms/"
	fi
fi

# ---------------------------------------------------------------------------
# 递归收集 MinGW 运行时依赖
#   MSYS2 的 Qt6Core 是动态链接的：pcre2 / zstd / double-conversion / b2 /
#   harfbuzz / freetype / glib / intl / iconv / brotli / md4c / zlib …
#   缺任何一个，程序启动就是 0xC0000135 (STATUS_DLL_NOT_FOUND)。
#   手工列举永远会漏，所以用 objdump -p 解析 PE 导入表后递归补齐。
#   （不用 ntldd：MSYS2 镜像上该包偶发校验失败，binutils 本来就有。）
# ---------------------------------------------------------------------------
if command -v objdump >/dev/null 2>&1; then
	resolve_deps() {
		local -a queue=("$@")
		local -a visited=()
		while [ ${#queue[@]} -gt 0 ]; do
			local cur="${queue[0]}"
			queue=("${queue[@]:1}")
			[ -f "$cur" ] || continue
			local skip=0 d
			for d in "${visited[@]}"; do
				if [ "$d" = "$cur" ]; then skip=1; break; fi
			done
			[ "$skip" -eq 1 ] && continue
			visited+=("$cur")

			local names
			names=$(objdump -p "$cur" 2>/dev/null | awk '/DLL Name:/ {print $3}')
			[ -z "$names" ] && continue

			local name src cand
			while IFS= read -r name; do
				[ -n "$name" ] || continue
				src=""
				for cand in \
					"$STAGING/$name" \
					"$STAGING/plugins/$name" \
					"$STAGING/platforms/$name" \
					"$MINGW_PREFIX/bin/$name" \
					"$MINGW_PREFIX/lib/$name"
				do
					[ -f "$cand" ] && src="$cand" && break
				done
				[ -z "$src" ] && continue
				if [ ! -f "$STAGING/$name" ]; then
					cp "$src" "$STAGING/" 2>/dev/null && queue+=("$STAGING/$name")
				fi
			done <<< "$names"
		done
	}

	deps_targets=()
	while IFS= read -r f; do deps_targets+=("$f"); done < <(
		find "$STAGING" -maxdepth 2 -type f \( -name '*.exe' -o -name '*.dll' \)
	)
	resolve_deps "${deps_targets[@]}"
	echo "-- dependency closure resolved ($(find "$STAGING" -maxdepth 1 -name '*.dll' | wc -l) root DLLs) --"
else
	echo "!! objdump not found; dependency set may be incomplete" >&2
fi

# 瘦身（失败不影响产物）
if [ -n "$STRIP" ]; then
	"$STRIP" "$STAGING"/*.dll "$STAGING"/*.exe \
		"$STAGING"/plugins/*.dll "$STAGING"/platforms/*.dll \
		"$STAGING"/styles/*.dll "$STAGING"/crypto/*.dll 2>/dev/null || true
fi

cp "$SRCDIR/COPYING" "$STAGING/" 2>/dev/null || true
cp "$SRCDIR/COPYING" "$STAGING/LICENSE.TXT" 2>/dev/null || true
cp "$SRCDIR/README.md" "$STAGING/README.TXT" 2>/dev/null || true

# NSIS 资源目录（注意用 src/. 形式，避免已存在时复制成 nsis/nsis）
mkdir -p "$STAGING/nsis"
cp -rf "$SRCDIR/nsis/." "$STAGING/nsis/" 2>/dev/null || true
# makensis 在 CI 上无法正确解析相对子目录，资源必须与 vigil.nsi 同目录
cp -f "$SRCDIR/nsis"/*.bmp "$SRCDIR/nsis"/*.ico "$STAGING/" 2>/dev/null || true
mkdir -p "$STAGING/classroom-teacher" "$STAGING/classroom-student"
cp -rf "$SRCDIR/tools/classroom-setup/teacher/." "$STAGING/classroom-teacher/" 2>/dev/null || true
cp -rf "$SRCDIR/tools/classroom-setup/student/." "$STAGING/classroom-student/" 2>/dev/null || true

# 安装脚本本体（configure_file 产物，位置随 CMake 版本略有差异）
if [ -f "$BUILDDIR/nsis/vigil.nsi" ]; then
	cp "$BUILDDIR/nsis/vigil.nsi" "$STAGING/"
else
	nsi=$(find "$BUILDDIR" -name vigil.nsi -not -path '*/vigil-win*/*' 2>/dev/null | head -1)
	[ -n "$nsi" ] && cp "$nsi" "$STAGING/"
fi

# ---- 关键文件校验 -------------------------------------------------------
for f in \
	vigil-server.exe vigil-master.exe vigil-cli.exe vigil-core.dll \
	Qt6Core.dll platforms/qwindows.dll welcome-page.bmp vigil.nsi
do
	[ -e "$STAGING/$f" ] || note_missing "$f"
done
[ -e "$STAGING"/libstdc++*.dll ] || note_missing "libstdc++-6.dll"
[ -e "$STAGING"/libgcc_s*.dll ] || note_missing "libgcc_s_seh-1.dll"
[ -e "$STAGING/crypto/libqca-ossl.dll" ] || note_missing "crypto/libqca-ossl.dll"
[ -e "$STAGING/tls/qopensslbackend.dll" ] || note_missing "tls/qopensslbackend.dll"

# ---- 依赖闭环校验 -------------------------------------------------------
# 凡是存在于 $MINGW_PREFIX/bin 的导入项，都必须被拷进 staging；
# 其余（KERNEL32 / USER32 等系统 DLL）由 Windows 自带，不算缺失。
if command -v objdump >/dev/null 2>&1; then
	unresolved=""
	while IFS= read -r f; do
		names=$(objdump -p "$f" 2>/dev/null | awk '/DLL Name:/ {print $3}')
		[ -z "$names" ] && continue
		while IFS= read -r name; do
			[ -n "$name" ] || continue
			[ -f "$STAGING/$name" ] && continue
			if [ -f "$MINGW_PREFIX/bin/$name" ] || [ -f "$MINGW_PREFIX/lib/$name" ]; then
				unresolved="${unresolved}"$'\n'"  $(basename "$f") needs $name"
			fi
		done <<< "$names"
	done < <(find "$STAGING" -maxdepth 2 -type f \( -name '*.exe' -o -name '*.dll' \) -not -path "$STAGING/nsis/*")
	if [ -n "$unresolved" ]; then
		echo "!! unresolved DLL dependencies:$unresolved" >&2
		exit 1
	fi
	echo "== dependency closure OK"
fi

echo "== staged files: $(find "$STAGING" -type f | wc -l)"
find "$STAGING" -maxdepth 1 -ls

if [ ${#MISSING[@]} -gt 0 ]; then
	echo "!! MISSING required files:" >&2
	for m in "${MISSING[@]}"; do echo "   - $m" >&2; done
	# 致命项：缺了安装包必然不可用
	for f in "$STAGING/platforms/qwindows.dll" "$STAGING/vigil-core.dll"; do
		if [ ! -e "$f" ]; then
			echo "FATAL: essential runtime file missing: $f" >&2
			exit 1
		fi
	done
	if [ ! -e "$STAGING/vigil.nsi" ]; then
		echo "FATAL: vigil.nsi not staged" >&2
		exit 1
	fi
fi

echo "== staging OK"
