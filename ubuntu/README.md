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

Restore in one step:

```bash
cd ubuntu && tar -cf - root | tar -xf - -C /
```

Add new files at their real path (e.g. `/usr/local/bin/ctx` →
`ubuntu/usr/local/bin/ctx`) instead of keeping copies at the top level.
