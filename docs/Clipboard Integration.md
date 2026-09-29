# Android Clipboard Integration from Ubuntu Chroot

## Problem

When working inside an Ubuntu chroot/sandbox running on Android (via Termux), commands and CLI scripts inside Ubuntu cannot copy text to the Android system clipboard.

Running `termux-clipboard-set` or `/data/data/com.termux/files/usr/bin/termux-clipboard-set` from within Ubuntu fails with:

```bash
-bash: /data/data/com.termux/files/usr/bin/termux-clipboard-set: No such file or directory
```

### Why Direct Execution Fails

1. **Bionic libc vs GNU libc**: Termux binaries are ELF executables compiled against Android's Bionic libc and dynamic linker (`/system/bin/linker64`). Inside an isolated rootfs/chroot, `/system` is not mounted.
2. **Android App & UID Sandbox**: `termux-clipboard-set` operates by broadcasting intents (`am broadcast`) to the `Termux:API` Android app. Android restricts these broadcasts to processes running in the Termux app UID context (`u0_a...`), not an arbitrary root chroot process.

---

## Solution: Localhost Socket Bridge

Because the Termux host and Ubuntu chroot share the same Linux network namespace and localhost (`127.0.0.1`), Termux can run a lightweight background listener using `socat` on localhost. 

Ubuntu sends clipboard data over a local TCP socket (`127.0.0.1:28282`), which Termux receives and immediately pipes into `termux-clipboard-set`. Inside Ubuntu, bash's native `/dev/tcp` interface is used so that no external packages (like `nc` or `netcat`) are required inside Ubuntu.

---

## Setup

### 1. Termux Side: Start the Clipboard Daemon

Install `socat` in Termux:

```bash
pkg install termux-api socat -y
```

Add the background daemon check to your `startlinux` script (or `~/.bashrc` in Termux):

```bash
# Start clipboard listener daemon if not already running
pgrep -f "TCP4-LISTEN:28282" > /dev/null || socat TCP4-LISTEN:28282,fork,bind=127.0.0.1,reuseaddr EXEC:"termux-clipboard-set" &
```

---

### 2. Ubuntu Side: Install the CLI Wrapper

Create `/usr/local/bin/termux-clipboard-set` inside Ubuntu:

```bash
cat << 'EOF' > /usr/local/bin/termux-clipboard-set
#!/bin/bash
TARGET="/dev/tcp/127.0.0.1/28282"

if [ $# -gt 0 ]; then
    echo -n "$*" > "$TARGET"
else
    cat > "$TARGET"
fi
EOF

chmod +x /usr/local/bin/termux-clipboard-set
ln -sf /usr/local/bin/termux-clipboard-set /usr/local/bin/clip
```

---

## Usage Examples

Inside Ubuntu, you can now pipe any output directly into the Android clipboard:

```bash
# Copy git diff
git diff | clip

# Copy arbitrary command output
cat file.txt | termux-clipboard-set

# Direct string arguments
clip "Hello Android Clipboard"
```

---

## Bonus: Context Helper (`ctx`)

To quickly format any source code file as Markdown and send it straight to the Android clipboard:

Create `/usr/local/bin/ctx`:

```bash
cat << 'EOF' > /usr/local/bin/ctx
#!/bin/bash
if [ -z "$1" ]; then
    echo "Usage: ctx <filename>" >&2
    exit 1
fi

file="$1"
if [ ! -f "$file" ]; then
    echo "Error: File '$file' does not exist." >&2
    exit 1
fi

ext="${file##*.}"
{
    echo "\`\`\`$ext"
    cat "$file"
    echo -e "\n\`\`\`"
} | /usr/local/bin/termux-clipboard-set

echo "Copied '$file' to Android clipboard."
EOF

chmod +x /usr/local/bin/ctx
```

Usage:
```bash
ctx some/File.kt
```
The file content wrapped in Markdown syntax highlighting will now be in your Android clipboard, ready to paste anywhere.
