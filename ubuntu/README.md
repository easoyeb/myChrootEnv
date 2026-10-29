# ubuntu/ — chroot system config backup

This folder is a **backup of the configuration files of the Ubuntu chroot** running
under Termux on Android (ARM64). It is not a full system image and not a dotfiles
showcase: it holds only the files that cannot be reinstalled from a package manager.

## How to read the layout

`ubuntu/` mirrors `/` of the chroot. A file's path here is its path on the system,
prefixed with `ubuntu/`:

| Backup path | System path |
| --- | --- |
| `ubuntu/root/.bashrc` | `/root/.bashrc` |
| `ubuntu/root/.tmux.conf` | `/root/.tmux.conf` |
| `ubuntu/root/.config/nvim/init.vim` | `/root/.config/nvim/init.vim` |
| `ubuntu/root/.config/starship.toml` | `/root/.config/starship.toml` |
| `ubuntu/root/bin/ctx` | `/root/bin/ctx` |
| `ubuntu/root/.zshrc` | `/root/.zshrc` |
| `ubuntu/root/bashmarks/` | `/root/bashmarks/` |
| `ubuntu/root/.local/bin/bashmarks.sh` | `/root/.local/bin/bashmarks.sh` |
| `ubuntu/root/.config/jj/config.toml` | `/root/.config/jj/config.toml` |
| `ubuntu/root/.config/opencode/opencode.json` | `/root/.config/opencode/opencode.json` |
| `ubuntu/usr/local/bin/ctx` | `/usr/local/bin/ctx` |
| `ubuntu/usr/local/bin/tg` | `/usr/local/bin/tg` |
| `ubuntu/usr/local/bin/clipg` | `/usr/local/bin/clipg` |
| `ubuntu/root/.gemini/settings.json` | `/root/.gemini/settings.json` |
| `ubuntu/root/.gemini/scripts/notify-hook.py` | `/root/.gemini/scripts/notify-hook.py` |
| `ubuntu/root/.gemini/antigravity-cli/settings.json` | `/root/.gemini/antigravity-cli/settings.json` |

`ubuntu/root/` is the home directory. Files under `/usr` go in `ubuntu/usr/`, and so on.

## Purpose

The chroot can be rebuilt from scratch by reinstalling packages. What cannot be
rebuilt is the hand-tuned work: shell config, aliases, helper scripts, agent
permission lists, and the small bridges that connect the chroot to Termux
(clipboard and notifications). This folder preserves exactly that.

It is also the answer to "where do I restore this to?" — the path is the instruction.

## Rules for agents working in this folder

1. **The path is the spec.** A file's location here must equal its live location
   with `ubuntu/` removed. Never place files at the top level of `ubuntu/`.
2. **Never invent a destination.** If an agent is asked to back up a live file,
   its destination is `ubuntu/` + the file's absolute path. If the live path is
   unknown, ask; do not guess.
3. **Refresh means replace, not merge.** When a live file has changed, copy it over
   the backup wholesale (`cp -p`). Do not hand-merge two versions.
4. **Verify, then commit.** After copying, confirm the backup is byte-identical
   (`cmp live backup`) and report the result. Commit only verified copies.
5. **No secrets.** Credentials are excluded on purpose. If a file contains a token,
   API key, private key, or OAuth credential, do not copy it — say which file was
   skipped and why. `opencode.json` uses the `YOURAPIKEY` placeholder; its `.bak`
   sibling is not tracked for this reason.
6. **No binaries.** Compiled executables are not backed up here (`trex-guard`,
   `mrcs`, `agy`), nor are `node_modules`, `pipx` venvs, caches, or agent session
   history (`brain/`, `conversations/`, `tmp/`).
7. **Submodules stay submodules.** `root/bashmarks/` is a pinned clone of
   `huyng/bashmarks`. Restores need `git submodule update --init`.
8. **Prose in this file, paths in git.** Keep this README short. Do not add
   per-file explanations scattered through the tree.

## Restoring

```bash
git submodule update --init
cd ubuntu && tar -cf - root usr | tar -xf - -C /
```

Restore specific files by path instead when only one thing broke, e.g.:

```bash
cp ubuntu/root/.bashrc /root/.bashrc
```

### Installing a single file from the backup

For executables and dotfiles, prefer `install` over `cp`:

```bash
install -m 755 ubuntu/usr/local/bin/clipg /usr/local/bin/clipg
install -m 644 ubuntu/root/.config/starship.toml /root/.config/starship.toml
install -m 600 ubuntu/root/.ssh/config /root/.ssh/config
```

Why `install` and not `cp`:

- **`-m` sets the mode explicitly**, so the result does not depend on how git checked
  the file out or what the umask is. Git only tracks the executable bit (mode
  `100644` or `100755`); it cannot store `600` versus `644`, so restore is the moment
  to set something sensitive back to `600`.
- **It replaces the inode** (unlink, then create). A process that already opened the
  file keeps reading the old contents, and other hard links are left alone — unlike
  `cp`, which writes through the existing inode and changes every link to it.
- **`-D` creates missing parent directories**, useful when restoring into a directory
  that does not exist yet:

  ```bash
  install -D -m 755 ubuntu/usr/local/bin/clipg /usr/local/bin/clipg
  ```

- It is one line with no side matter, so it reads as "this file, this place, this
  mode" — the backup path already states where the file belongs.

Use `cp -a` only when you want the source's owner, group, and timestamps preserved
as well as the mode, which matters for a bulk restore, not a single file. For bulk,
the `tar` pipeline above keeps all of that.

## What is deliberately not here

| Excluded | Why |
| --- | --- |
| `~/.ssh`, `~/.gnupg`, `~/.config/gh`, `~/.android/adbkey` | Credentials — keep an encrypted copy elsewhere |
| `~/.gemini/oauth_creds.json` | Login credential |
| `/opt/android-sdk-custom`, `~/.gradle`, `~/.npm`, caches | Reinstallable |
| `~/.local/share/pipx`, `node_modules` | Reinstallable |
| Agent session logs and databases | Large, and not configuration |

## Related docs

The guides in `../docs/` explain the systems these files configure:
clipboard integration, phone notifications, terminal setup, and the Antigravity
CLI patch.
