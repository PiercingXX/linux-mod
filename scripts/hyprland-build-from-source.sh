#!/bin/bash
# Build Hyprland from source on Void Linux with faster profiles.
# Usage: sudo BUILD_PROFILE=core bash hyprland-build-from-source.sh

set -euo pipefail

YELLOW='\033[1;33m'
GREEN='\033[1;32m'
NC='\033[0m'

# Version pins
HYPRUTILS_VERSION="v0.13.1"
HYPRLANG_VERSION="v0.6.7"
HYPRLAND_PROTOCOLS_VERSION="v0.7.0"
HYPRWAYLAND_SCANNER_VERSION="v0.4.6"
HYPRWIRE_VERSION="v0.3.1"
HYPRLOCK_VERSION="v0.5.1"
HYPRIDLE_VERSION="v0.3.1"
HYPRGRAPHICS_VERSION="v0.5.1"
HYPRPAPER_VERSION="v0.7.6"
AQUAMARINE_VERSION="v0.9.3"
HYPRCURSOR_VERSION="v0.1.11"
HYPRLAND_VERSION="v0.55.3"

BUILD_DIR="${BUILD_DIR:-/tmp/hyprland-build}"
JOBS=$(nproc 2>/dev/null || echo 2)
BUILD_PROFILE="${BUILD_PROFILE:-core}"
REUSE_SOURCES="${REUSE_SOURCES:-1}"

if [ "$BUILD_PROFILE" != "core" ] && [ "$BUILD_PROFILE" != "full" ]; then
    echo "Unsupported BUILD_PROFILE: $BUILD_PROFILE (expected: core|full)" >&2
    exit 1
fi

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Install build dependencies
echo -e "${YELLOW}Installing build dependencies...${NC}"
sudo xbps-install \
    base-devel cmake meson ninja pkg-config \
    ccache \
    git llvm clang \
    wayland wayland-devel wayland-protocols \
    SPIRV-Headers SPIRV-Tools-devel \
    glslang-devel \
    libxcb libxcb-devel \
    libXcursor-devel \
    xcb-util xcb-util-devel xcb-util-image-devel \
    xcb-util-cursor-devel xcb-util-keysyms-devel \
    xcb-util-renderutil-devel xcb-util-wm-devel \
    libxkbcommon libxkbcommon-devel \
    cairo-devel pango-devel \
    lua53-devel libffi-devel \
    re2-devel muparser-devel lcms2-devel \
    libzip-devel tomlplusplus-devel \
    pugixml-devel \
    file-devel \
    libjpeg-turbo-devel libwebp-devel librsvg-devel \
    libdrm-devel libinput-devel \
    pixman-devel \
    libseat-devel \
    wlroots-devel vulkan-loader-devel

export CCACHE_DIR="${CCACHE_DIR:-$HOME/.cache/ccache}"
export CCACHE_MAXSIZE="${CCACHE_MAXSIZE:-20G}"
export PKG_CONFIG_PATH="/usr/local/lib64/pkgconfig:/usr/local/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
export CMAKE_PREFIX_PATH="/usr/local:${CMAKE_PREFIX_PATH:-}"
export LDFLAGS="-L/usr/local/lib64 -L/usr/local/lib ${LDFLAGS:-}"
export LD_LIBRARY_PATH="/usr/local/lib64:/usr/local/lib:${LD_LIBRARY_PATH:-}"

ensure_local_ldconfig_paths() {
    sudo tee /etc/ld.so.conf.d/zz-usr-local.conf >/dev/null <<'EOF'
/usr/local/lib64
/usr/local/lib
EOF
}

ensure_libmagic_dev_shim() {
    # Prefer the real development package when available.
    if pkg-config --exists libmagic 2>/dev/null && [ -f /usr/include/magic.h ]; then
        # Clean up an old compatibility shim so it doesn't shadow the real header.
        if [ -f /usr/local/include/magic.h ]; then
            sudo rm -f /usr/local/include/magic.h
        fi
        if [ -f /usr/local/lib/pkgconfig/libmagic.pc ]; then
            sudo rm -f /usr/local/lib/pkgconfig/libmagic.pc
        fi
        return 0
    fi

    echo -e "${YELLOW}Creating libmagic development shim for hyprgraphics...${NC}"
    sudo mkdir -p /usr/local/include /usr/local/lib/pkgconfig

    if [ ! -f /usr/local/include/magic.h ]; then
        sudo tee /usr/local/include/magic.h >/dev/null <<'EOF'
#ifndef MAGIC_H
#define MAGIC_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct magic_set* magic_t;

#define MAGIC_NONE 0x000000
#define MAGIC_DEBUG 0x000001
#define MAGIC_SYMLINK 0x000002
#define MAGIC_COMPRESS 0x000004
#define MAGIC_MIME_TYPE 0x000010

magic_t magic_open(int flags);
void magic_close(magic_t cookie);
int magic_load(magic_t cookie, const char* filename);
const char* magic_file(magic_t cookie, const char* filename);
const char* magic_buffer(magic_t cookie, const void* buffer, size_t length);

#ifdef __cplusplus
}
#endif

#endif
EOF
    fi

    if [ ! -f /usr/local/lib/pkgconfig/libmagic.pc ]; then
        sudo tee /usr/local/lib/pkgconfig/libmagic.pc >/dev/null <<'EOF'
prefix=/usr
exec_prefix=${prefix}
libdir=/usr/lib
includedir=/usr/local/include

Name: libmagic
Description: File type identification library
Version: 5.46
Libs: -L${libdir} -lmagic
Cflags: -I${includedir}
EOF
    fi

    export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
}

ensure_libmagic_dev_shim
ensure_local_ldconfig_paths

update_repo() {
    local name=$1 repo=$2 version=$3
    local dir="${BUILD_DIR}/${name}"

    if [ "$REUSE_SOURCES" = "1" ] && [ -d "$dir/.git" ]; then
        echo -e "${YELLOW}Reusing source for ${name}; fetching ${version}...${NC}"
        git -C "$dir" fetch --tags --force origin
        git -C "$dir" checkout -f "$version"
        git -C "$dir" submodule update --init --recursive
    else
        rm -rf "$dir"
        git clone --depth 1 --recursive -b "$version" "$repo" "$dir"
    fi
}

patch_hyprland_for_void_toolchain() {
    local srcdir=$1

    # Hyprland v0.55.3 searches for Lua 5.5 module names by default.
    # Void ships Lua 5.3, so expand lookup aliases for pkg-config.
    sed -i 's/pkg_search_module(LUA REQUIRED IMPORTED_TARGET GLOBAL lua55 lua5.5 lua-55 lua-5.5 lua>=5.5 lua<5.6)/pkg_search_module(LUA REQUIRED IMPORTED_TARGET GLOBAL lua53 lua5.3 lua-5.3 lua lua55 lua5.5 lua-55 lua-5.5)/' "${srcdir}/CMakeLists.txt"

    # GCC 14 libstdc++ misses C++26 std::string + std::string_view operator+.
    sed -i 's@getRuntimeDir() + "/" + instanceSignature + "/" + filename;@getRuntimeDir() + "/" + instanceSignature + "/" + std::string(filename);@' "${srcdir}/hyprctl/src/main.cpp"
    sed -i 's@std::string{"0x"} + value)@std::string{"0x"} + std::string(value))@' "${srcdir}/src/config/shared/parserUtils/ParserUtils.cpp"

    # GCC 14 preprocessor does not support C++26 #embed yet.
    perl -0777 -i -pe 's@inline constexpr char\s+EXAMPLE_CONFIG_BYTES_LUA\[\]\s*=\s*\{\n#embed "\.\./\.\./\.\./example/hyprland\.lua"\n\};\n\ninline constexpr std::string_view EXAMPLE_CONFIG_LUA = \{EXAMPLE_CONFIG_BYTES_LUA, sizeof\(EXAMPLE_CONFIG_BYTES_LUA\)\};@inline constexpr std::string_view EXAMPLE_CONFIG_LUA = R"#(\n-- example config embedding unavailable on this toolchain\nhl.config({ autogenerated = true })\n)#";@s' "${srcdir}/src/config/lua/DefaultConfig.hpp"

    # GCC 14 rejects conditional operator over mixed CXCBConnection/nullptr types.
    perl -0777 -i -pe 's@return m_connection \? \*m_connection : nullptr;@if (!m_connection)\n            return nullptr;\n        return *m_connection;@' "${srcdir}/src/xwayland/XWM.hpp"

    # Aquamarine in Void exposes logFunction, not logConnection.
    perl -0777 -i -pe 's@SP<Hyprutils::CLI::CLoggerConnection> conn = makeShared<Hyprutils::CLI::CLoggerConnection>\(Log::logger->hu\(\)\);\n    conn->setLogLevel\(Log::DEBUG\);\n    conn->setName\("aquamarine"\);\n    options\.logConnection = std::move\(conn\);@options.logFunction = nullptr;@s' "${srcdir}/src/Compositor.cpp"

    # Older aquamarine in Void has no AQ_BACKEND_NULL enum value.
    sed -i 's@Aquamarine::eBackendType backendType = Aquamarine::eBackendType::AQ_BACKEND_NULL;@Aquamarine::eBackendType backendType = Aquamarine::eBackendType::AQ_BACKEND_HEADLESS;@' "${srcdir}/src/helpers/SystemInfo.cpp"
    sed -i 's@if (i->type() == Aquamarine::eBackendType::AQ_BACKEND_NULL || i->type() == Aquamarine::eBackendType::AQ_BACKEND_HEADLESS)@if (i->type() == Aquamarine::eBackendType::AQ_BACKEND_HEADLESS)@' "${srcdir}/src/helpers/SystemInfo.cpp"

    # GCC 14 lacks std::vector::insert_range.
    perl -0777 -i -pe 's@requestedModes\.insert_range\(requestedModes\.end\(\), sortedModes \| std::views::reverse\);@auto sortedModesReversed = sortedModes | std::views::reverse;\n        requestedModes.insert(requestedModes.end(), sortedModesReversed.begin(), sortedModesReversed.end());@s' "${srcdir}/src/helpers/Monitor.cpp"
}

patch_hyprwire_for_void_toolchain() {
    local srcdir=$1

    # GCC 14 on Void lacks std::vector::append_range (C++23 library gap).
    # Patch hyprwire sources to use a portable append helper.
    mkdir -p "${srcdir}/src/helpers"
    cat > "${srcdir}/src/helpers/AppendRangeCompat.hpp" <<'EOF'
#pragma once

#include <cstdint>
#include <vector>

namespace Hyprwire {
template <typename Range>
inline void appendRangeCompat(std::vector<uint8_t>& dst, Range&& range) {
    for (auto&& v : range)
        dst.push_back(static_cast<uint8_t>(v));
}
} // namespace Hyprwire
EOF

    while IFS= read -r srcfile; do
        if ! grep -q 'helpers/AppendRangeCompat.hpp' "$srcfile"; then
            sed -i '1i #include <helpers/AppendRangeCompat.hpp>' "$srcfile"
        fi
        perl -0777 -i -pe 's/([A-Za-z_][A-Za-z0-9_\.]*)\.append_range\((.+?)\);/appendRangeCompat($1, $2);/g' "$srcfile"
    done < <(rg -l 'append_range\(' "${srcdir}/src")
}

# Function to build and install
build_cmake() {
    local name=$1 repo=$2 version=$3
    echo -e "${YELLOW}Building ${name} (${version})...${NC}"

    update_repo "$name" "$repo" "$version"

    if [ "$name" = "Hyprland" ]; then
        patch_hyprland_for_void_toolchain "${BUILD_DIR}/${name}"
    elif [ "$name" = "hyprwire" ]; then
        patch_hyprwire_for_void_toolchain "${BUILD_DIR}/${name}"
    fi

    cd "${BUILD_DIR}/${name}"
    rm -rf build
    mkdir -p build
    cd build

    cmake --no-warn-unused-cli \
        -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_C_COMPILER_LAUNCHER=ccache \
        -DCMAKE_CXX_COMPILER_LAUNCHER=ccache \
        .. || return 1
    cmake --build . --config Release -j"$JOBS" || return 1
    sudo cmake --install . || return 1

    echo -e "${GREEN}✓ ${name} installed${NC}"
}

build_protocols() {
    echo -e "${YELLOW}Installing hyprland-protocols (${HYPRLAND_PROTOCOLS_VERSION})...${NC}"

    update_repo "hyprland-protocols" "https://github.com/hyprwm/hyprland-protocols.git" "$HYPRLAND_PROTOCOLS_VERSION"

    sudo mkdir -p /usr/share/wayland-protocols
    sudo cp -r "${BUILD_DIR}/hyprland-protocols"/protocols/* /usr/share/wayland-protocols/
    echo -e "${GREEN}✓ hyprland-protocols installed${NC}"
}

# Build core in dependency order (faster "happy medium")
build_cmake "hyprutils" "https://github.com/hyprwm/hyprutils.git" "$HYPRUTILS_VERSION"
build_cmake "hyprlang" "https://github.com/hyprwm/hyprlang.git" "$HYPRLANG_VERSION"
build_protocols
build_cmake "hyprwayland-scanner" "https://github.com/hyprwm/hyprwayland-scanner.git" "$HYPRWAYLAND_SCANNER_VERSION"
build_cmake "aquamarine" "https://github.com/hyprwm/aquamarine.git" "$AQUAMARINE_VERSION"
build_cmake "hyprgraphics" "https://github.com/hyprwm/hyprgraphics.git" "$HYPRGRAPHICS_VERSION"
build_cmake "hyprwire" "https://github.com/hyprwm/hyprwire.git" "$HYPRWIRE_VERSION"
build_cmake "hyprcursor" "https://github.com/hyprwm/hyprcursor.git" "$HYPRCURSOR_VERSION"
build_cmake "Hyprland" "https://github.com/hyprwm/Hyprland.git" "$HYPRLAND_VERSION"

if [ "$BUILD_PROFILE" = "full" ]; then
    build_cmake "hyprlock" "https://github.com/hyprwm/hyprlock.git" "$HYPRLOCK_VERSION"
    build_cmake "hypridle" "https://github.com/hyprwm/hypridle.git" "$HYPRIDLE_VERSION"
    build_cmake "hyprpaper" "https://github.com/hyprwm/hyprpaper.git" "$HYPRPAPER_VERSION"
fi

echo -e "${GREEN}=== Hyprland build complete! ===${NC}"
if command -v Hyprland >/dev/null 2>&1; then
    Hyprland --version || true
elif command -v hyprland >/dev/null 2>&1; then
    hyprland --version || true
fi

# Run ldconfig to update library cache
sudo ldconfig

echo -e "${GREEN}✓ All Hyprland components built and installed successfully!${NC}"
