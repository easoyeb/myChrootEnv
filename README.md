# myChrootEnv

A specialized environment setup for Android development and AI-assisted coding on ARM64 Linux systems (optimized for Chroot/Termux environments).

This repository provides scripts to automate the installation of a custom ARM64 Android SDK and the Gemini CLI.

## Repository
`git@github.com:easoyeb/myChrootEnv.git`

## Features
- **Custom ARM64 Android SDK:** Downloads and configures a specific Android SDK build compatible with ARM64 Linux (musl).
- **AAPT2 Global Override:** Automatically configures Gradle to use the local ARM64 AAPT2 binary, bypassing Maven issues on non-standard environments.
- **Node.js & Gemini CLI:** Sets up Node.js 20 and installs the Gemini CLI for AI-assisted development.
- **Optimized Gradle Settings:** Pre-configures `gradle.properties` with flags suitable for low-resource or mobile-based build environments.

## Installation

### 1. Setup Gemini CLI and Node.js
You can install Node.js 20 and the Gemini CLI with this one-liner:
```bash
curl -sSL https://raw.githubusercontent.com/easoyeb/myChrootEnv/main/setup-gemini.sh | bash
```
Or manually:
```bash
chmod +x setup-gemini.sh
./setup-gemini.sh
```

### 2. Install Android SDK
Download the ARM64 Android SDK and configure your environment with this one-liner:
```bash
curl -sSL https://raw.githubusercontent.com/easoyeb/myChrootEnv/main/install.sh | bash
```
Or manually:
```bash
chmod +x install.sh
./install.sh
```

## Configuration Details
The `install.sh` script modifies `~/.gradle/gradle.properties` to ensure stability on mobile devices:
- `org.gradle.daemon=false`
- `org.gradle.parallel=false`
- `org.gradle.caching=false`
- `kotlin.compiler.execution.strategy=in-process`
- `android.aapt2FromMavenOverride`: Points to the local ARM64 AAPT2.

## Usage
After installation, you can build Android projects using:
```bash
./gradlew assembleDebug --no-daemon
```

## License
MIT
