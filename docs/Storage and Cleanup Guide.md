# Storage Analysis & Cleanup Guide

In an Android/Termux chroot development environment, disk space is limited and shared with mobile storage. Build tools (Gradle, Android SDK, Cargo, NPM, Flutter) aggressively cache files and leave behind gigabytes of temporary data.

This guide explains **how to find disk space hogs**, **where they hide in this chroot environment**, and **how to safely clean them**.

---

## 1. How to Scan and Locate Disk Hogs

### Step 1: Check Total Disk Usage & Mounts
Check how much total space is consumed:
```bash
df -h
```

### Step 2: Top-Level System Directory Scan
Find which top-level directories (`/root`, `/opt`, `/usr`, `/tmp`, `/var`) take the most space:
```bash
du -hd 1 / 2>/dev/null | sort -hr | head -n 15
```
*   `-h`: Human-readable format (MB/GB).
*   `-d 1` (or `--max-depth=1`): Restrict search to 1 level deep so you don't get flooded with millions of files.
*   `2>/dev/null`: Suppress permission warnings on `/proc` and `/sys`.
*   `sort -hr`: Sort numerically in reverse order (largest on top).

### Step 3: Scan User Home Directory (`/root` or `~`)
Scan hidden and visible folders in your home directory:
```bash
du -hd 1 /root 2>/dev/null | sort -hr | head -n 25
```

### Step 4: Scan Project Build Artifacts
Locate all `build/`, `.gradle/`, and `node_modules/` folders across your projects:
```bash
find /root/Projects -maxdepth 3 -type d \( -name "build" -o -name ".gradle" -o -name "node_modules" \) 2>/dev/null | xargs -r du -sh 2>/dev/null | sort -hr
```

---

## 2. Common Storage Culprits in this Environment

### 1. Android SDK Leftover Temp Files (`/opt/android-sdk-custom/android-sdk/.temp`)
*   **Why it happens:** When `sdkmanager` or custom setup scripts unpack SDK/NDK packages, temporary installation folders (like `PackageOperation01`) often remain in the `.temp` directory.
*   **How to check:**
    ```bash
    du -sh /opt/android-sdk-custom/android-sdk/.temp
    ```
*   **How to clean (100% Safe):**
    ```bash
    rm -rf /opt/android-sdk-custom/android-sdk/.temp/*
    ```

---

### 2. System Temporary Directory (`/tmp`)
*   **Why it happens:** Build tools like `cargo` (`cargo-install*`), `flutter_tools`, Python venvs, and SQLite temporary native libraries store unpacks in `/tmp`. In chroot environments without auto-tmpfs clearing on reboot, `/tmp` can grow to several gigabytes.
*   **How to check:**
    ```bash
    du -hd 1 /tmp 2>/dev/null | sort -hr | head -n 10
    ```
*   **How to clean (Safe):**
    ```bash
    rm -rf /tmp/cargo-install* /tmp/flutter_tools.* /tmp/droidlate_venv
    # Or clean older temporary files:
    find /tmp -mindepth 1 -maxdepth 1 -mtime +2 -exec rm -rf {} +
    ```

---

### 3. Gradle Cache & Wrapper Distros (`~/.gradle`)
*   **Why it happens:** Every Gradle version used by different Android projects downloads its own Gradle distribution wrapper (`wrapper/dists/`) and caches transformed dependencies (`caches/8.13`, `caches/9.0.0`, `caches/9.2.0`, `caches/modules-2`). Over time, this easily exceeds 10–15 GB.
*   **How to check:**
    ```bash
    du -hd 2 /root/.gradle 2>/dev/null | sort -hr | head -n 15
    ```
*   **How to clean (Safe - will re-download only active project dependencies on demand):**
    ```bash
    # Clean versioned caches and build caches
    rm -rf /root/.gradle/caches/*

    # Clean unused wrapper downloads
    rm -rf /root/.gradle/wrapper/dists/*
    ```

---

### 4. Project `build/` Directories (`~/Projects/*/build`)
*   **Why it happens:** Active Android/Kotlin compilation generates APKs, intermediate DEX files, AAPT2 dumps, and class files inside each project's `build/` and `app/build/` directory.
*   **How to clean:**
    *   **Option A (Project-by-project):**
        ```bash
        cd /root/Projects/YourProject
        ./gradlew clean
        ```
    *   **Option B (Bulk clean all project build folders):**
        ```bash
        find /root/Projects -maxdepth 3 -type d -name "build" -exec rm -rf {} +
        ```

---

### 5. Package Manager Stores & Caches (PNPM, NPM, PIP, APT)
*   **PNPM Global Store (`~/.local/share/pnpm`):**
    ```bash
    pnpm store prune
    ```
*   **NPM Cache (`~/.npm`):**
    ```bash
    npm cache clean --force
    ```
*   **Python Pip Cache (`~/.cache/pip`):**
    ```bash
    pip cache purge
    ```
*   **APT Package Archive (`/var/cache/apt/archives`):**
    ```bash
    apt-get clean
    apt-get autoremove
    ```

---

### 6. AI Agent Workspace Clones (`~/.gemini/tmp`)
*   **Why it happens:** Antigravity / Gemini CLI creates temporary subagent branch checkouts in `~/.gemini/tmp/` during multi-agent workflows.
*   **How to check:**
    ```bash
    du -hd 1 /root/.gemini/tmp 2>/dev/null | sort -hr
    ```
*   **How to clean (Safe when agents are idle):**
    ```bash
    rm -rf /root/.gemini/tmp/*
    ```

---

## 3. Quick System Cleanup Routine

Run this single routine whenever your chroot warns about low storage:

```bash
# 1. Clean temporary install directories
rm -rf /opt/android-sdk-custom/android-sdk/.temp/*
rm -rf /root/.gemini/tmp/*
rm -rf /tmp/cargo-install* /tmp/flutter_tools.*

# 2. Prune package manager caches
npm cache clean --force 2>/dev/null
pnpm store prune 2>/dev/null
pip cache purge 2>/dev/null
apt-get clean

# 3. Clean Gradle cache (frees 5-10+ GB)
rm -rf /root/.gradle/caches/*
rm -rf /root/.gradle/wrapper/dists/*

# 4. Check results
df -h
```
