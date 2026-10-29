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
            # Routine file operations inside workspace do not prompt
            pass

        else:
            # MCP or unknown external tools
            needs_attention = True
            title = f"agy: {tool_name}"
            content = f"Action: {tool_name}"

        if needs_attention:
            send_notification(title, content)

        # Always return {"decision": "ask"} to keep normal manual prompts active
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
