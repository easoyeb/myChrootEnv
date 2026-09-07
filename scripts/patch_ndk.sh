#!/bin/bash
# Universal NDK Patcher for Ubuntu-on-Android (ARM64)
# This script makes official Google NDKs work in proot/chroot environments.

NDK_DIR=$1

if [ -z "$NDK_DIR" ] || [ ! -d "$NDK_DIR" ]; then
    echo "Usage: $0 /path/to/android-ndk-folder"
    exit 1
fi

# Convert to absolute path
NDK_DIR=$(cd "$NDK_DIR" && pwd)
echo "------------------------------------------"
echo "Patching NDK at: $NDK_DIR"
echo "------------------------------------------"

# 1. Patch architecture detection (Map aarch64 to x86_64 folder)
COMMON_SH="$NDK_DIR/build/tools/ndk_bin_common.sh"
if [ -f "$COMMON_SH" ]; then
    sed -i 's/arm64) HOST_ARCH=arm64;;/arm64|aarch64) HOST_ARCH=x86_64;;/' "$COMMON_SH"
    echo "[✓] Patched ndk_bin_common.sh"
else
    echo "[!] Warning: ndk_bin_common.sh not found. Skipping."
fi

# 2. Mass Symlink Native Tools
BIN_DIR="$NDK_DIR/toolchains/llvm/prebuilt/linux-x86_64/bin"
if [ -d "$BIN_DIR" ]; then
    cd "$BIN_DIR" || exit
    echo "[*] Symlinking LLVM tools..."
    for tool in clang clang++ lld ld.lld ld64.lld llvm-ar llvm-as llvm-nm llvm-objcopy llvm-objdump llvm-ranlib llvm-readelf llvm-strip; do
        if [ -f "$tool" ] || [ -L "$tool" ]; then
            # Backup original if it's not already a symlink
            [ ! -L "$tool" ] && mv "$tool" "${tool}.bak" 2>/dev/null
            
            # Link to system 18 versions
            case $tool in
                clang|clang++) ln -sf /usr/bin/${tool}-18 $tool ;;
                lld|ld.lld|ld64.lld) ln -sf /usr/bin/ld.lld-18 $tool ;;
                *) ln -sf /usr/bin/${tool}-18 $tool ;;
            esac
        fi
    done
    
    # Special case for clang-18 (some NDKs use versioned names)
    ln -sf /usr/bin/clang-18 clang-18 2>/dev/null
    echo "[✓] Symlinked compiler tools"
else
    echo "[!] Error: LLVM bin directory not found!"
fi

# 3. Symlink Make
MAKE_BIN="$NDK_DIR/prebuilt/linux-x86_64/bin/make"
if [ -d "$(dirname "$MAKE_BIN")" ]; then
    [ -f "$MAKE_BIN" ] && [ ! -L "$MAKE_BIN" ] && mv "$MAKE_BIN" "${MAKE_BIN}.bak"
    ln -sf /usr/bin/make "$MAKE_BIN"
    echo "[✓] Symlinked make"
fi

# 4. Fix Linker Libraries across all ABIs and API levels
SYSROOT_LIB="$NDK_DIR/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib"
CLANG_VER=$(ls "$NDK_DIR/toolchains/llvm/prebuilt/linux-x86_64/lib/clang/" 2>/dev/null | head -n 1)
CLANG_RT_DIR="$NDK_DIR/toolchains/llvm/prebuilt/linux-x86_64/lib/clang/$CLANG_VER/lib/linux"

patch_abi() {
    local abi_name="$1"
    local rt_arch="$2"
    local sysroot_dir="$SYSROOT_LIB/$abi_name"
    
    if [ -d "$sysroot_dir" ]; then
        echo "[*] Fixing libraries for $abi_name..."
        local builtins="$CLANG_RT_DIR/libclang_rt.builtins-${rt_arch}-android.a"
        local unwind="$CLANG_RT_DIR/$rt_arch/libunwind.a"
        local atomic="$CLANG_RT_DIR/$rt_arch/libatomic.a"

        for api_dir in "$sysroot_dir"/*/; do
            if [ -d "$api_dir" ]; then
                [ -f "$builtins" ] && ln -sf "$builtins" "$api_dir" 2>/dev/null || true
                [ -f "$unwind" ] && ln -sf "$unwind" "$api_dir" 2>/dev/null || true
                [ -f "$atomic" ] && ln -sf "$atomic" "$api_dir" 2>/dev/null || true
                echo "INPUT(libclang_rt.builtins-${rt_arch}-android.a libunwind.a)" > "${api_dir}libgcc.a"
            fi
        done
        echo "[✓] Fixed $abi_name sysroot API levels"
    fi
}

patch_abi "aarch64-linux-android" "aarch64"
patch_abi "arm-linux-androideabi" "arm"
patch_abi "i686-linux-android" "i386"
patch_abi "x86_64-linux-android" "x86_64"

echo "------------------------------------------"
echo "Patching Complete!"
echo "------------------------------------------"
