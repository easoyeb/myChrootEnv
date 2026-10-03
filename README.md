# myChrootEnv

> [!IMPORTANT]
> This repository contains documentation and tooling for **proot** and **chroot** environments (e.g., Ubuntu, Debian, or Kali inside Termux). It is **NOT** intended for native Termux.

A documentation portal and configuration suite for **ARM64 Linux environments**, toolchain patching, and AI workflows.

---

## 📚 Documentation Site

This repository uses **VitePress** to serve and build the documentation site.

```bash
npm install        # Install dependencies
npm run docs:dev   # Start local dev server
npm run docs:build # Build static site
```

---


## Detailed Documentation & Guides

For a deep dive into how these setups work and how to troubleshoot them, refer to these guides:

- 📱 **[Building Android Apps (AGP 8.x)](./docs/Build%20with%20Termux.md)**: Detailed breakdown of the ARM64 SDK, AAPT2 overrides, and Gradle optimizations.
- 💙 **[Flutter Setup](./docs/Flutter%20Setup.md)**: Integrating Flutter with the ARM64-native SDK and fixing `cmdline-tools` path issues.
- ⚙️ **[NDK & Native Code Setup](./docs/NDK%20Setup.md)**: How to patch the Android NDK to use native ARM64 toolchains (`clang`, `make`, `ninja`) and fix linker errors.
- ⌨️ **[Kotlin LSP Setup (Neovim)](./docs/Kotlin%20LSP%20Setup.md)**: Working setup for Kotlin Language Server with Neovim 0.11+ in a chroot environment.
- 🔑 **[SSH Setup](./docs/SSH%20Setup.md)**: Accessing the Ubuntu sandbox via SSH from Termux for a seamless remote-like development experience.
- 🐚 **[Terminal Setup (Starship & ble.sh)](./docs/Terminal%20Setup.md)**: Guide to configuring a modern, auto-suggesting bash prompt, including fixes for chroot environments.
- 🐚 **[Bash Config](https://github.com/easoyeb/myChrootEnv/blob/main/ubuntu/.bashrc)**: Pre-configured `.bashrc` loaded with AI aliases, history search (`fzf`), auto-suggestions (`ble.sh`), and the Starship prompt.
- ✨ **[Starship Config](https://github.com/easoyeb/myChrootEnv/blob/main/ubuntu/.config/starship.toml)**: Clean, single-line "Pastel Powerline" prompt configuration.
- 🌑 **[Neovim Config](https://github.com/easoyeb/myChrootEnv/blob/main/ubuntu/.config/nvim/init.vim)**: Pre-configured `init.vim` with autocompletion, LSP, and mobile optimizations.
- 🛠️ **[Termux Configuration](https://github.com/easoyeb/myChrootEnv/blob/main/termux/termux.properties)**: Optimized `termux.properties` with specialized Git and Vim macros.
- 🛠️ **[Maintenance & Recovery Guide](./docs/Maintenance%20Guide.md)**: Critical environment variables, Git configurations, and recovery steps to prevent setup headaches.
- 🔮 **[Antigravity CLI Patching](./docs/Antigravity%20CLI%20Patching.md)**: How the CLI is patched to respect the 39-bit memory limit of Android kernels, and how to maintain it without an AI helper.
- 💾 **[Tmux Persistence Setup](./docs/Tmux%20Persistence%20Setup.md)**: Continuous auto-saving and auto-restoration for tmux sessions after power outages or system reboots.
- 🧹 **[Storage Analysis & Cleanup Guide](./docs/Storage%20and%20Cleanup%20Guide.md)**: How to diagnose storage hogs, clean multi-gigabyte Gradle and Android SDK temp files, and free disk space.
- ⚡ **[Gradle Local Environment Automation](./docs/Gradle%20Local%20Environment%20Automation.md)**: How to automatically load project-level `local-env.gradle.kts` without `-I` flags and zero Git pollution via `~/.gradle/init.d/`.
- 📋 **[Android Clipboard Integration](./docs/Clipboard%20Integration.md)**: Transparent clipboard bridge enabling Ubuntu CLI tools, `git diff`, and scripts (`clip`, `ctx`) to copy straight to Android's clipboard via Termux.
- 🔔 **[Antigravity Phone Notifications](./docs/Antigravity%20Phone%20Notifications.md)**: Real-time notification bridge from Ubuntu chroot to Android lock screen via Termux, alerting whenever Antigravity CLI needs manual approval, asks a question, or completes a long task.



---

## 📄 License

MIT
