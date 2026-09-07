#!/usr/bin/env bash
set -e

# ==============================================================================
# Setup Gradle Global Project-Aware Init Loader
# ==============================================================================
# This script installs a zero-impact loader into ~/.gradle/init.d/
# It automatically loads project-level 'local-env.gradle.kts' if present,
# eliminating the need to pass '-I local-env.gradle.kts' on every build.
# ==============================================================================

INIT_DIR="$HOME/.gradle/init.d"
LOADER_FILE="$INIT_DIR/local-env-loader.init.gradle.kts"

echo "Configuring Gradle Global Init Loader..."
mkdir -p "$INIT_DIR"

cat << 'EOF' > "$LOADER_FILE"
// Automatically loads project-level 'local-env.gradle.kts' if present
gradle.projectsLoaded {
    val localEnv = rootProject.file("local-env.gradle.kts")
    if (localEnv.exists()) {
        apply(from = localEnv)
    }
}
EOF

chmod 644 "$LOADER_FILE"

echo "✅ Gradle Global Init Loader installed at:"
echo "   $LOADER_FILE"
echo ""
echo "You can now run Gradle commands (e.g. './gradlew installDebug') directly"
echo "without needing the '-I local-env.gradle.kts' flag!"
