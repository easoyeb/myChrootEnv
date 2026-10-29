# termux/ — Termux app config backup

This folder is a **backup of the configuration files of Termux itself** (the Android
app, not the Ubuntu chroot inside it). Chroot config lives in [`../ubuntu/`](../ubuntu/).

## How to read the layout

`termux/` mirrors the Termux installation. A file's path here is its path on the
device with the prefix `/data/data/com.termux/files` removed:

| Backup path | Device path |
| --- | --- |
| `termux/home/.termux/termux.properties` | `~/.termux/termux.properties` |
| `termux/home/startlinux` | `~/startlinux` |

So `termux/home/` is Termux's home directory, and `termux/usr/` would be `$PREFIX`.
The path after `termux/` **is** the destination — do not flatten files to the top level.

## Purpose

Termux is the host for everything else. Its settings (extra-keys row, macros,
`allow-external-apps`) and the `startlinux` launcher are typed in by hand and are not
installed by any package. This folder preserves them so the phone can be set up again
without rediscovering each tweak.

`startlinux` is also where the two chroot bridges are started — the clipboard
listener on port 28282 and the notification listener on 28283. Those pair with the
Ubuntu-side code in [`../ubuntu/root/.config/`](../ubuntu/root/.config/).

## Rules for agents working in this folder

1. **The path is the spec.** Destination is `termux/` + device path with
   `/data/data/com.termux/files` stripped. If the live path is unknown, ask.
2. **Refresh replaces.** Copy the live file over the backup wholesale (`cp -p`);
   never hand-merge two versions.
3. **Verify then commit.** Confirm byte-identical (`cmp live backup`) and report it.
4. **No secrets.** Do not copy tokens, API keys, private keys, or `authorized_keys`.
   Say which file was skipped and why.
5. **No packages or binaries.** Track the *list* of installed packages as text; do
   not copy `$PREFIX`, `node_modules`, caches, or downloaded binaries.
6. **Keep `.termux/` as `.termux/`.** The directory name is part of the path and is
   not interchangeable with `termux/`.

## Restoring

Termux needs its own storage and package base first (`pkg install ...`), then:

```bash
# from inside Termux, with this repo cloned
cp -a termux/home/. ~/
termux-reload-settings
```

`termux-reload-settings` applies `termux.properties` without restarting the app.

## What is deliberately not here

| Excluded | Why |
| --- | --- |
| `~/.ssh`, `~/.config/gh` | Credentials |
| `~/.termux/termux.properties` backups / old copies | Only the active file is tracked |
| `$PREFIX`, `node_modules`, caches | Reinstallable; the package list covers it |
| Termux:Widget shortcuts, Tasker intents (not used) | Nothing to restore |

## Related docs

[`../docs/Terminal Setup.md`](../docs/Terminal%20Setup.md),
[`../docs/Clipboard Integration.md`](../docs/Clipboard%20Integration.md), and
[`../docs/Antigravity Phone Notifications.md`](../docs/Antigravity%20Phone%20Notifications.md)
describe the systems these files configure.
