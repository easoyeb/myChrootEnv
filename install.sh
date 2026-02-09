#!/usr/bin/env bash
set -e

# ===== CONFIG =====
SDK_VER="36.0.0"
AAPT_VER="36.1.0"
SDK_BASE="/opt/android-sdk-custom"
SDK_ROOT="$SDK_BASE/android-sdk"
SDK_URL="https://github.com/HomuHomu833/android-sdk-custom/releases/download/${SDK_VER}/android-sdk-aarch64-linux-musl.tar.xz"

# ===== INSTALL ANDROID SDK (ARM64) =====
mkdir -p "$SDK_BASE"
cd "$SDK_BASE"

if [ ! -d "$SDK_ROOT" ]; then
  wget -q --show-progress "$SDK_URL"
  tar -xf android-sdk-aarch64-linux-musl.tar.xz
fi

# ===== ENVIRONMENT =====
export ANDROID_SDK_ROOT="$SDK_ROOT"
export ANDROID_HOME="$SDK_ROOT"
export PATH="$ANDROID_SDK_ROOT/platform-tools:$PATH"

# ===== VERIFY ADB =====
adb version

# ===== VERIFY AAPT2 (ARM64 REQUIRED) =====
"$ANDROID_SDK_ROOT/build-tools/$AAPT_VER/aapt2" version

# ===== FORCE GRADLE TO USE ARM64 AAPT2 =====
mkdir -p ~/.gradle
GRADLE_PROP="$HOME/.gradle/gradle.properties"

grep -q "android.aapt2FromMavenOverride" "$GRADLE_PROP" 2>/dev/null || \
echo "android.aapt2FromMavenOverride=$ANDROID_SDK_ROOT/build-tools/$AAPT_VER/aapt2" >> "$GRADLE_PROP"

# ===== RECOMMENDED STABILITY FLAGS (PHONE BUILDS) =====
grep -q "org.gradle.daemon" "$GRADLE_PROP" 2>/dev/null || cat >> "$GRADLE_PROP" <<EOF

org.gradle.daemon=false
org.gradle.parallel=false
org.gradle.caching=false
kotlin.compiler.execution.strategy=in-process
EOF

# ===== CLEAN POISONED CACHES (RUN ONCE) =====
./gradlew --stop 2>/dev/null || true
rm -rf ~/.gradle/caches

echo "✅ ARM64 Android SDK installed"
echo "✅ ARM64 AAPT2 forced globally"
echo "✅ Ready to build with: ./gradlew assembleDebug --no-daemon"
