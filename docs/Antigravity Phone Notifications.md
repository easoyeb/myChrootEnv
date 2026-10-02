# Antigravity Phone Notifications from Ubuntu Chroot

## Problem

When running long agentic tasks with Antigravity CLI (`agy`) inside an isolated Ubuntu chroot on Android, tasks frequently stall on:
1. **Permission prompts**: Commands not present in the allowlist.
2. **Interactive input**: Questions directed to the user (`ask_question`).
3. **Completion**: Tasks finishing while the user is away from the device.

If you switch away from Termux or put the phone in your pocket, you might return an hour later to find `agy` paused on the very first step.

### Why Direct Notification Fails

1. **Environment Isolation**: `termux-notification` and other Termux:API tools run in Android's user space, relying on Android Intents broadcast by the Termux app UID (`u0_a...`).
2. **Missing Bionic/Android Subsystem**: The Ubuntu chroot has no direct access to the Android IPC binder or Termux:API helper binaries. Running `termux-notification` inside Ubuntu fails.

---

## Solution: Localhost Socket Bridge

Termux and the Ubuntu chroot share the Linux network namespace and localhost loopback (`127.0.0.1`). 

Similar to the clipboard bridge on port `28282`:
1. **Termux** runs a lightweight `socat` TCP daemon on `127.0.0.1:28283` that pipes incoming text into a notification handler script.
2. **Ubuntu** uses Antigravity CLI's native lifecycle hooks (`PreToolUse` and `Stop`) to dispatch concise event summaries over `/dev/tcp/127.0.0.1/28283`.
3. **Smart Filtering**: The hook reads your existing allowlist (`~/.gemini/antigravity-cli/settings.json`) so routine allowed commands (`git status`, `ls`, `./gradlew`) execute silently, and your phone **only buzzes when user attention is truly required**.

```
[Ubuntu Chroot: agy]
  hooks.json (PreToolUse & Stop)
    │
    ▼
  notify-hook.py (Filter against allowlist & format alert)
    │
    ▼ (TCP connection to 127.0.0.1:28283)
[Android / Termux]
  socat daemon (127.0.0.1:28283)
    │
    ▼
  termux-notify-server.sh
    │
    ▼
  termux-notification (High-priority lock screen alert)
```

---

## Setup Guide

### 1. Termux Host Setup

#### Step 1.1: Create Notification Server Script
In Termux, create `~/.local/bin/termux-notify-server.sh`:

```bash
mkdir -p ~/.local/bin
cat << 'EOF' > ~/.local/bin/termux-notify-server.sh
#!/data/data/com.termux/files/usr/bin/bash
# Read title on line 1, message on line 2
read -r title
read -r content

title="${title:-Antigravity}"
content="${content:-Attention needed}"

# Fire high-priority notification with a fixed ID to update cleanly
termux-notification --id "agy-attention" --title "$title" --content "$content" --priority high
EOF
chmod +x ~/.local/bin/termux-notify-server.sh
```

#### Step 1.2: Automate Bridge in Termux Launcher (`startlinux`)
Add the daemon check to your Termux startup script:

```bash
# Start notification bridge only if not already running
if ! pgrep -f "TCP4-LISTEN:28283" >/dev/null; then
    socat TCP4-LISTEN:28283,bind=127.0.0.1,reuseaddr,fork EXEC:"$HOME/.local/bin/termux-notify-server.sh" &
fi
```

---

### 2. Ubuntu Chroot Setup

#### Step 2.1: Create Notification Hook Script
Inside Ubuntu, create `/root/.gemini/scripts/notify-hook.py`:

```bash
mkdir -p /root/.gemini/scripts
cat << 'EOF' > /root/.gemini/scripts/notify-hook.py
#!/usr/bin/python3
import sys
import json
import socket
import re
import os

BRIDGE_HOST = "127.0.0.1"
BRIDGE_PORT = 28283

def send_notification(title, content):
    try:
        s = socket.create_connection((BRIDGE_HOST, BRIDGE_PORT), timeout=1.0)
        msg = f"{title}\n{content}\n".encode("utf-8")
        s.sendall(msg)
        s.close()
    except Exception:
        pass

def load_allow_list(workspace_paths):
    allow_list = []
    global_settings_path = os.path.expanduser("~/.gemini/antigravity-cli/settings.json")
    if os.path.exists(global_settings_path):
        try:
            with open(global_settings_path, "r", encoding="utf-8") as f:
                data = json.load(f)
                allow_list.extend(data.get("permissions", {}).get("allow", []))
        except Exception:
            pass

    for wp in (workspace_paths or []):
        for sub in [".gemini/antigravity-cli/settings.json", ".agents/settings.json"]:
            wpath = os.path.join(wp, sub)
            if os.path.exists(wpath):
                try:
                    with open(wpath, "r", encoding="utf-8") as f:
                        data = json.load(f)
                        allow_list.extend(data.get("permissions", {}).get("allow", []))
                except Exception:
                    pass
    return allow_list

def is_allowed_rule(cmd, allow_list):
    cmd = cmd.strip()
    for rule in allow_list:
        if rule.startswith("command(") and rule.endswith(")"):
            pattern = rule[8:-1].strip()
            if cmd == pattern or cmd.startswith(pattern + " ") or cmd.startswith(pattern + "\t"):
                return True
    return False

def is_command_fully_allowed(full_cmd, allow_list):
    sub_cmds = re.split(r";|&&|\|\||\|", full_cmd)
    for sub in sub_cmds:
        sub = sub.strip()
        if not sub:
            continue
        parts = sub.split()
        while parts and "=" in parts[0] and not parts[0].startswith(("./", "/")):
            parts.pop(0)
        cleaned = " ".join(parts)
        if not is_allowed_rule(cleaned, allow_list):
            return False
    return True

def main():
    event_type = sys.argv[1] if len(sys.argv) > 1 else "auto"
    raw_input = sys.stdin.read()
    if not raw_input.strip():
        print("{}")
        return

    try:
        payload = json.loads(raw_input)
    except Exception:
        print("{}")
        return

    if event_type == "auto":
        if "toolCall" in payload:
            event_type = "pre-tool"
        elif "terminationReason" in payload:
            event_type = "stop"

    if event_type == "pre-tool":
        tool_call = payload.get("toolCall", {})
        tool_name = tool_call.get("name", "")
        args = tool_call.get("args", {})
        workspace_paths = payload.get("workspacePaths", [])
        allow_list = load_allow_list(workspace_paths)

        needs_attention = False
        title = f"agy: {tool_name}"
        content = "Permission needed"

        if tool_name == "ask_question":
            needs_attention = True
            title = "agy: Question"
            questions = args.get("questions", [])
            q_text = questions[0].get("question", "") if questions else "Waiting for your answer"
            content = q_text[:80].replace("\n", " ")

        elif tool_name == "run_command":
            cmd = args.get("CommandLine", "")
            if not is_command_fully_allowed(cmd, allow_list):
                needs_attention = True
                title = "agy: Permission Needed"
                content = cmd[:80].replace("\n", " ")

        elif tool_name in ("search_web", "read_url_content"):
            needs_attention = True
            title = "agy: Web Access"
            query_or_url = args.get("query") or args.get("Url") or tool_name
            content = str(query_or_url)[:80]

        elif tool_name in ("view_file", "write_to_file", "replace_file_content"):
            # Routine file operations inside workspace execute without prompting
            pass

        else:
            # MCP or unknown external tools
            needs_attention = True
            title = f"agy: {tool_name}"
            content = f"Action: {tool_name}"

        if needs_attention:
            send_notification(title, content)

        # IMPORTANT: Always return {"decision": "ask"} to keep manual prompts active
        print(json.dumps({"decision": "ask"}))

    elif event_type == "stop":
        fully_idle = payload.get("fullyIdle", True)
        if fully_idle:
            reason = payload.get("terminationReason", "unknown")
            err = payload.get("error", "")

            title = "agy: Finished"
            if reason == "model_stop":
                content = "Task finished normally"
            elif reason == "max_steps_exceeded":
                title = "agy: Step Limit"
                content = "Reached maximum step limit"
            elif reason == "error":
                title = "agy: Stopped on Error"
                content = err[:80] if err else "Unknown error"
            else:
                content = f"Stopped: {reason}"

            send_notification(title, content)

        print("{}")
    else:
        print("{}")

if __name__ == "__main__":
    main()
EOF
chmod +x /root/.gemini/scripts/notify-hook.py
```

Create `/root/.gemini/scripts/notify-hook.sh`:
```bash
cat << 'EOF' > /root/.gemini/scripts/notify-hook.sh
#!/bin/bash
exec /root/.gemini/scripts/notify-hook.py "$@"
EOF
chmod +x /root/.gemini/scripts/notify-hook.sh
```

#### Step 2.2: Register Global Lifecycle Hooks
Configure `/root/.gemini/config/hooks.json`:

```bash
cat << 'EOF' > /root/.gemini/config/hooks.json
{
  "phone-notifier": {
    "PreToolUse": [
      {
        "matcher": ".*",
        "hooks": [
          {
            "type": "command",
            "command": "/root/.gemini/scripts/notify-hook.sh pre-tool"
          }
        ]
      }
    ],
    "Stop": [
      {
        "type": "command",
        "command": "/root/.gemini/scripts/notify-hook.sh stop"
      }
    ]
  }
}
EOF
```

---

## Crucial Technical Details

### Why `{"decision": "ask"}` is Required
In Antigravity CLI:
- Omitting the `decision` field or returning `{}` from a `PreToolUse` hook causes the agent engine to **deny** the tool execution automatically (`tool call denied by pre-tool hook`).
- Returning `{"decision": "allow"}` would bypass permissions and auto-approve without user consent (violating safety).
- Returning `{"decision": "ask"}` instructs the engine to follow its normal permission check: if the action is allowlisted, it runs; if not, it presents the manual approval prompt in your terminal.

### Background Task Guard
The `Stop` event payload includes `"fullyIdle": true/false`. If background subagents or terminal tasks are still running, `fullyIdle` is `false`. The hook checks this field to ensure notifications only fire when the agent has truly concluded all work.

---

## Troubleshooting & Maintenance

1. **No Notifications Appearing**:
   - Verify bridge is running in Termux: `ss -tulpn | grep 28283`.
   - Send manual test packet from Ubuntu:
     ```bash
     printf "Test Title\nTest Content\n" > /dev/tcp/127.0.0.1/28283
     ```
   - Ensure Termux:API has Android system notification permissions (Android Settings $\rightarrow$ Apps $\rightarrow$ Termux:API $\rightarrow$ Notifications).
2. **Android Killing Bridge in Sleep**:
   - In Termux, run `termux-wake-lock`.
   - Set Battery usage for Termux and Termux:API to **Unrestricted** in Android system settings.
3. **Disabling Notifications Temporarily**:
   - In `/root/.gemini/config/hooks.json`, set `"enabled": false` inside the `"phone-notifier"` block.
