# Automatically Loading Local Gradle Environment Scripts Without Flags or Git Tracking

> **Platform:** ARM64 Linux / chroot / proot / Termux / AndroidIDE  
> **Topic:** Gradle Build Optimization, Init Scripts, Git Hygiene  

Building complex Android projects directly on an Android device (via chroot/proot/Termux) often requires aggressive local adjustments: targeting a single ABI (`arm64-v8a`), capping worker threads to prevent OOM/thermal throttling, substituting remote Maven dependencies with locally compiled `.aar` binaries, and configuring custom native library paths.

Traditionally, developers manage this via an init script passed manually on the command line:
```bash
./gradlew installDebug -I local-env.gradle.kts
```

However, having to type `-I local-env.gradle.kts` on every single invocation is tedious and error-prone. Forgetting the flag triggers full unoptimized builds, fetches remote dependencies, or exhausts device RAM.

This document details the **zero-flag, zero-git-pollution solution** using Gradle's **Global Initialization Scripts** (`~/.gradle/init.d/`) combined with a **Dynamic Project Loader**.

---

## Table of Contents

1. [The Challenge](#the-challenge)
2. [How Gradle Initialization Scripts Work](#how-gradle-initialization-scripts-work)
3. [The Solution: Dynamic Project-Aware Loader](#the-solution-dynamic-project-aware-loader)
4. [The Three Components](#the-three-components)
   - [1. Global Loader Script (`~/.gradle/init.d/`)](#1-global-loader-script-gradleinitd)
   - [2. Project Environment Script (`local-env.gradle.kts`)](#2-project-environment-script-local-envgradlekts)
   - [3. Git Stealth via `.git/info/exclude`](#3-git-stealth-via-gitinfoexclude)
5. [Step-by-Step Setup](#step-by-step-setup)
6. [Verification & Output](#verification--output)
7. [Multi-Project Safety & Isolation](#multi-project-safety--isolation)
8. [Summary of Benefits](#summary-of-benefits)

---

## The Challenge

When developing locally on mobile hardware, we face two conflicting requirements:
1. **Aggressive Local Overrides:** We need local build optimizations (e.g. limiting workers, filtering ABIs, using local AARs) that must NOT be committed to the project's repository or shared with CI/team members.
2. **Seamless Workflow:** The overrides must take effect automatically without requiring developers or AI coding agents to append `-I local-env.gradle.kts` every time they run `./gradlew installDebug` or `./gradlew compileDebugKotlin`.
3. **Strict Git Cleanliness:** `git status` must remain completely clean. Neither `gradlew`, `build.gradle.kts`, `settings.gradle.kts`, nor `.gitignore` may be altered.

---

## How Gradle Initialization Scripts Work

Gradle has built-in support for initialization scripts ("init scripts"). These scripts run before the build starts and have access to the `Gradle` lifecycle object.

Gradle automatically discovers and executes init scripts located in:
* `USER_HOME/.gradle/init.d/*.gradle` or `USER_HOME/.gradle/init.d/*.gradle.kts`
* `USER_HOME/.gradle/init.gradle` or `USER_HOME/.gradle/init.gradle.kts`

Because `USER_HOME/.gradle/` lives completely outside any project repository, **Git has zero awareness of it**.

However, placing project-specific logic directly in `~/.gradle/init.d/` would pollute **all** other Gradle builds on the machine. The key innovation is to use a **generic dynamic loader**.

---

## The Solution: Dynamic Project-Aware Loader

Instead of hardcoding project-specific build hacks in `~/.gradle/init.d/`, we install a tiny **loader script** that intercepts project evaluation:

```
┌────────────────────────────────────────────────────────┐
│               Gradle Build Invocation                  │
│             (e.g., ./gradlew installDebug)             │
└───────────────────────────┬────────────────────────────┘
                            │
                            ▼
┌────────────────────────────────────────────────────────┐
│       ~/.gradle/init.d/local-env-loader.init.gradle.kts│
│       Hooks into gradle.projectsLoaded { ... }         │
└───────────────────────────┬────────────────────────────┘
                            │
             Does rootProject have local-env.gradle.kts?
                            ├─── NO ───► Do nothing (<1ms)
                            │
                            └─── YES ──► apply(from = localEnv)
                                                │
                                                ▼
                                 ┌──────────────────────────────┐
                                 │ Project's local-env.gradle.kts│
                                 │ (Applies local optimizations)│
                                 └──────────────────────────────┘
```

When you invoke `./gradlew`:
1. Gradle starts and loads `~/.gradle/init.d/local-env-loader.init.gradle.kts`.
2. The loader registers a `gradle.projectsLoaded` listener.
3. When the project hierarchy is ready, it checks if `rootProject.file("local-env.gradle.kts")` exists.
4. If found, it dynamically evaluates the script via `apply(from = localEnv)`.
5. If not found (or in any other project), it exits immediately with zero side-effects.

---

## The Three Components

### 1. Global Loader Script (`~/.gradle/init.d/`)

Create `/root/.gradle/init.d/local-env-loader.init.gradle.kts`:

```kotlin
// Location: ~/.gradle/init.d/local-env-loader.init.gradle.kts
gradle.projectsLoaded {
    val localEnv = rootProject.file("local-env.gradle.kts")
    if (localEnv.exists()) {
        apply(from = localEnv)
    }
}
```

#### Why `projectsLoaded`?
* Init scripts run in the `Gradle` scope before settings or projects are instantiated.
* `gradle.projectsLoaded` fires as soon as the project tree (including `rootProject`) is created, but **before** individual project `build.gradle.kts` files are evaluated.
* Calling `apply(from = localEnv)` evaluates `local-env.gradle.kts` against the `Gradle` instance, allowing top-level `allprojects { ... }` blocks to configure all subprojects.

---

### 2. Project Environment Script (`local-env.gradle.kts`)

Placed in the root of the project (e.g. `/root/Projects/mpvRex/local-env.gradle.kts`).

This script contains local performance tuning, dependency substitution, and ABI restrictions. Because it runs inside an init script context, dynamic reflection is used to safely configure the Android Gradle Plugin (AGP) without compile-time classpath conflicts.

```kotlin
import java.util.Properties

allprojects {
    afterEvaluate {
        if (name == "app") {
            val android = extensions.findByName("android") ?: return@afterEvaluate
            
            // Only apply if mpvex.dev.mode=true in local.properties
            val localProperties = Properties()
            val localPropertiesFile = rootProject.file("local.properties")
            if (localPropertiesFile.exists()) {
                localProperties.load(localPropertiesFile.inputStream())
            }
            val isDevMode = localProperties.getProperty("mpvex.dev.mode", "false").toBoolean()

            if (isDevMode) {
                // 1. Substitute remote dependency with local .aar in lib/ if present
                val libDir = rootProject.file("lib")
                val localAar = libDir.listFiles()?.firstOrNull { it.name.endsWith(".aar") }
                if (localAar != null) {
                    configurations.all {
                        exclude(group = "com.github.sfsakhawat999", module = "mpvRex-libmpv")
                    }
                    dependencies.add("implementation", rootProject.files(localAar))
                    println(">>> [Dev Mode] Substituted remote dependency with local AAR: ${localAar.name}")
                }

                // 2. Point JNI libs to lib/ directory via reflection
                val sourceSets = android.javaClass.getMethod("getSourceSets").invoke(android) as NamedDomainObjectContainer<*>
                val main = sourceSets.getByName("main")
                val jniLibs = main.javaClass.getMethod("getJniLibs").invoke(main)
                val setMethod = jniLibs.javaClass.getMethod("srcDirs", Array<Any>::class.java)
                setMethod.invoke(jniLibs, arrayOf<Any>(file("lib"), file("../lib")))

                // 3. Fast ARM64 build only (strip other ABIs)
                val defaultConfig = android.javaClass.getMethod("getDefaultConfig").invoke(android)
                val ndk = defaultConfig.javaClass.getMethod("getNdk").invoke(defaultConfig)
                @Suppress("UNCHECKED_CAST")
                val abiFilters = ndk.javaClass.getMethod("getAbiFilters").invoke(ndk) as MutableSet<String>
                abiFilters.clear()
                abiFilters.add("arm64-v8a")

                // 4. Performance Optimizations for Termux / Mobile SoC
                gradle.startParameter.maxWorkerCount = 2

                // 5. Disable Compose source information for faster compilation
                val composeCompiler = extensions.findByName("composeCompiler")
                if (composeCompiler != null) {
                    try {
                        val setIncludeSourceInfo = composeCompiler.javaClass.getMethod("setIncludeSourceInformation", Boolean::class.java)
                        setIncludeSourceInfo.invoke(composeCompiler, false)
                        println(">>> Compose Compiler source info disabled for faster builds")
                    } catch (e: Exception) {
                        // Signature differences ignored
                    }
                }

                println(">>> Local Environment optimizations applied to :app (via dynamic access)")
            }
        }
    }
}
```

---

### 3. Git Stealth via `.git/info/exclude`

To ensure `local-env.gradle.kts` and local documentation do not dirty the git tree or get accidentally committed, use Git's local-only exclusion list:

Add to `<project-root>/.git/info/exclude`:
```text
local-env.gradle.kts
rules.md
lib/
```

Unlike `.gitignore`, `.git/info/exclude` is **never committed to the repository**. It stays local to that specific machine/clone.

---

## Step-by-Step Setup

### Step 1: Create the Global Init Directory and Loader

Run the following command on your machine:

```bash
mkdir -p ~/.gradle/init.d
cat << 'EOF' > ~/.gradle/init.d/local-env-loader.init.gradle.kts
gradle.projectsLoaded {
    val localEnv = rootProject.file("local-env.gradle.kts")
    if (localEnv.exists()) {
        apply(from = localEnv)
    }
}
EOF
```

### Step 2: Add `local-env.gradle.kts` to Your Project

Place your custom build logic in `<project-root>/local-env.gradle.kts`.

### Step 3: Hide It From Git

```bash
echo "local-env.gradle.kts" >> .git/info/exclude
```

### Step 4: Enable Dev Mode in `local.properties`

In `<project-root>/local.properties`:
```properties
mpvex.dev.mode=true
```

---

## Verification & Output

Run Gradle directly without any `-I` flag:

```bash
./gradlew installDebug
```

Output:
```text
> Configure project :app
WARNING: The option setting 'android.aapt2FromMavenOverride=/opt/android-sdk-custom/android-sdk/build-tools/36.1.0/aapt2' is experimental.
>>> [Dev Mode] Substituted remote com.github.sfsakhawat999:mpvRex-libmpv with local AAR: app-release.aar
>>> Local Environment optimizations applied to :app (via dynamic access)

...
> Task :app:compileDebugKotlin
> Task :app:packageDebug
> Task :app:installDebug
Installing APK 'app-debug.apk' on 'emulator-5554 - 13' for :app:debug
Installed on 1 device.

BUILD SUCCESSFUL in 10m 58s
44 actionable tasks: 24 executed, 20 up-to-date
```

Check `git status`:
```bash
git status
# Output:
# On branch master
# nothing to commit, working tree clean
```

---

## Multi-Project Safety & Isolation

If you work on multiple repositories on the same system, you may wonder if this loader could affect them.

* **Default Behavior:** If a project does not have `local-env.gradle.kts`, `localEnv.exists()` returns `false` and nothing runs. The check takes less than 1 millisecond.
* **Optional Project-Name Lock:** If you want 100% strict isolation to only a specific project (e.g., `mpvRex`), edit `~/.gradle/init.d/local-env-loader.init.gradle.kts`:

```kotlin
gradle.projectsLoaded {
    if (rootProject.name == "mpvRex") {
        val localEnv = rootProject.file("local-env.gradle.kts")
        if (localEnv.exists()) {
            apply(from = localEnv)
        }
    }
}
```

---

## Summary of Benefits

| Feature | Old Method (`-I flag`) | New Method (`~/.gradle/init.d/`) |
| :--- | :--- | :--- |
| **Command** | `./gradlew installDebug -I local-env.gradle.kts` | `./gradlew installDebug` |
| **Git Working Tree** | Clean (if ignored) | **100% Clean** |
| **Tracked Files Changed** | None | **None** |
| **Error Prone?** | Yes (easy to forget flag) | **No (automatic)** |
| **IDE / Script Compatibility** | Requires manual IDE config | **Transparently works everywhere** |
| **Cross-Project Pollution** | None | **None** (guarded by file check) |
