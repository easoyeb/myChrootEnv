# termux/ — Termux app config backup

This folder is a **backup of the configuration files of Termux itself** (the Android
app, not the Ubuntu chroot inside it). Chroot config lives in [`../ubuntu/`](../ubuntu/).

## How to read the layout

`termux/` mirrors the Termux installation. A file's path here is its path on the
device with the prefix `/data/data/com.termux/files` removed:

| Backup path | Device path |
| --- | --- |
| `termux/home/.bashrc` | `~/.bashrc` |
| `termux/home/startlinux` | `~/startlinux` |
| `termux/home/.local/bin/startlinux` | `~/.local/bin/startlinux` |
| `termux/home/.local/bin/termux-notify-server.sh` | `~/.local/bin/termux-notify-server.sh` |
| `termux/home/.termux/termux.properties` | `~/.termux/termux.properties` |
| `termux/home/.termux/colors.properties` | `~/.termux/colors.properties` |
| `termux/usr/bin/tsu` | `$PREFIX/bin/tsu` (`/data/data/com.termux/files/usr/bin/tsu`) |
| `termux/packages.txt` | (not a file on the device — see below) |

So `termux/home/` is Termux's home directory, and `termux/usr/` is `$PREFIX`.
The path after `termux/` **is** the destination — do not flatten files to the top level.

`termux/usr/bin/tsu` is a modified copy of [cswl/tsu](https://github.com/cswl/tsu)
(reports `8.6.0`). Keep the local copy rather than reinstalling the package if it
has been edited — check `diff` against upstream before overwriting.

`packages.txt` is the exception: it is a generated inventory (`name | version`), not
a live file, so it sits at the top level of `termux/`.

## Purpose

Termux is the host for everything else. Its settings (extra-keys row, macros,
`allow-external-apps`), shell config, and the launcher are typed in by hand and are
not installed by any package. This folder preserves them so the phone can be set up
again without rediscovering each tweak.

`startlinux` is also where the two chroot bridges are started — the clipboard
listener on port 28282, the clipboard read listener on 28284, and the notification
listener on 28283. Those pair with the
Ubuntu-side code in [`../ubuntu/root/.config/`](../ubuntu/root/.config/).

### Two `startlinux` files, on purpose

- `~/startlinux` — older, minimal fixed-sequence version. Kept for reference.
- `~/.local/bin/startlinux` — the real launcher. It is idempotent: it only starts
  adbd, the Ubuntu SSH service, and each bridge if they are not already running.
  Because `~/.local/bin` is on `PATH`, typing `startlinux` runs this one.

## Rules for agents working in this folder

1. **The path is the spec.** Destination is `termux/` + device path with
   `/data/data/com.termux/files` stripped. If the live path is unknown, ask.
2. **Refresh replaces.** Copy the live file over the backup wholesale (`cp -p`);
   never hand-merge two versions.
3. **Verify then commit.** Confirm byte-identical (`cmp live backup`) and report it.
4. **No secrets.** Do not copy tokens, API keys, private keys, or `authorized_keys`.
   Say which file was skipped and why. `~/.git-credentials` is empty but excluded
   on principle.
5. **No binaries.** Do not copy `~/.termux/font.ttf` (1.9 MB font), `$PREFIX`,
   `node_modules`, caches, or `~/.cache`.
6. **Keep the dot-directories.** `.termux/` and `.local/` are part of the path and
   must not be renamed or flattened.
7. **Preserve executable bits.** Scripts under `home/` must stay `+x`.

## Restoring

Termux needs its own storage and package base first:

```bash
pkg update
cut -d'|' -f1 < termux/packages.txt | sed 's/ *$//' | xargs pkg install -y
cp -a termux/home/. ~/
install -m 755 termux/usr/bin/tsu "$PREFIX/bin/tsu"
termux-reload-settings
```

`termux-reload-settings` applies `termux.properties` without restarting the app.

## What is deliberately not here

| Excluded | Why |
| --- | --- |
| `~/.ssh`, `~/.config/gh`, `~/.git-credentials` | Credentials |
| `~/.termux/font.ttf` | Binary asset; install the font separately |
| `~/.bash_history`, `~/.viminfo`, `~/.sdirs` | Runtime state |
| `~/.cache`, `$PREFIX`, `node_modules` | Reinstallable; `packages.txt` covers it |
| `Projects/`, `storage/`, `bashmarks/` | Code and external storage, backed up elsewhere |

## Related docs

[`../docs/Terminal Setup.md`](../docs/Terminal%20Setup.md),
[`../docs/Clipboard Integration.md`](../docs/Clipboard%20Integration.md), and
[`../docs/Antigravity Phone Notifications.md`](../docs/Antigravity%20Phone%20Notifications.md)
describe the systems these files configure.
