# ubuntu/ — root filesystem backup

This folder mirrors `/` of the Ubuntu chroot. A file's path here is its path on
the system, prefixed with `ubuntu/`.

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

Restore in one step (after `git submodule update --init`, which populates
`ubuntu/root/bashmarks/`):

```bash
cd ubuntu && tar -cf - root | tar -xf - -C /
```

Add new files at their real path (e.g. `/usr/local/bin/ctx` →
`ubuntu/usr/local/bin/ctx`) instead of keeping copies at the top level.
