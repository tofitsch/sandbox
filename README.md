# sandbox

`sandbox` drops you into a disposable AlmaLinux 9 container that behaves roughly like lxplus:
CVMFS available, current directory as the workdir, your real `$HOME` invisible. It picks the
right image for the machine it's on — see [Modes](#modes).

- **Workdir** — `$PWD` is mounted at `/work`. Files you create there stay owned by you.
- **Persistent home** — `/home/$USER` survives restarts, so a Claude Code login is done once.
- **CVMFS** — mounted at container start, or passed through from the host on lxplus.
- **Shell init** — `bashrc.sh` in this repo is mounted read-only and sourced at every start, so
  edits take effect on the next `sandbox` with no rebuild.
- **Editor config** — `~/.rootrc` and `~/.config/nvim` from the host are mounted read-only into
  the container home, if present. Neovim is installed in the image.
- **Git config** — `~/.gitconfig` from the host is mounted read-only into the container home, if
  present.
- **Claude Code rules** — `CLAUDE.md` in this repo is mounted read-only as the container's global
  `~/.claude/CLAUDE.md`, so it applies to Claude Code for any project run inside the sandbox.

## Modes

The launcher switches on the hostname: `lxplus*` selects lxplus mode, anything else local mode.
Force it with `SANDBOX_MODE=local|lxplus`.

| | local | lxplus |
|---|---|---|
| Image | `sandbox:alma9`, built locally from `image/local` | `ghcr.io/tofitsch/sandbox:alma9-lxplus`, pulled (never built on lxplus) |
| CVMFS | client installed in the image, mounted by the entrypoint | host `/cvmfs` bind-mounted read-only |
| Privileges | `--cap-add SYS_ADMIN --device /dev/fuse` for the FUSE mount | none |
| User | entrypoint recreates your UID and drops privileges | runs as the container's root, which *is* you |
| Home | Docker volume `sandbox-home` | `~/.sandbox-home` on AFS |
| CVMFS cache | Docker volume `sandbox-cvmfs` | the host's |

The user difference is forced: rootless podman on lxplus has no subuid range, so uid 0 is the
only id mapped into the container and there is nothing to drop privileges *to*. That maps back to
your account on the host, so files written to `/work` still come out owned by you.

## Layout

```
sandbox                     # the launcher, goes on your PATH
bashrc.sh                   # sourced in every container shell — put your aliases here
CLAUDE.md                   # global Claude Code rules for every project run inside the sandbox
image/local/Dockerfile      # AlmaLinux 9 + CVMFS + Node + Claude Code
image/local/entrypoint.sh   # mounts CVMFS, matches your UID, drops privileges
image/lxplus/Dockerfile     # the same without CVMFS — the host provides it
image/lxplus/entrypoint.sh  # shell init only
image/lxplus/publish.sh     # builds and pushes the lxplus image — run off lxplus
```

## Install

Requires Docker and Linux (tested on Ubuntu 22.04).

```bash
mkdir -p ~/install ~/bin
git clone git@github.com:tofitsch/sandbox.git ~/install/sandbox
ln -s ~/install/sandbox/sandbox ~/bin/sandbox
chmod +x ~/bin/sandbox
```

Make sure `~/bin` is on your PATH. If not:

```bash
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc && exec bash
```

The launcher finds `image/` and `bashrc.sh` relative to itself, so the symlink is enough — don't
copy the script on its own.

## Install on lxplus

`docker` on lxplus is a shim over rootless podman, and your account has no `/etc/subuid` range —
the container namespace maps a single id, so anything requiring a second uid/gid fails with
`lchown`/`chown: invalid argument`. That breaks two different things: *pulling* an image with
files owned by another uid/gid (e.g. `/usr/bin/write`, setgid `tty`), and *building* one, since a
live `RUN` step (e.g. `dnf` installing `openssh`, which ships the setuid `ssh-keysign`) hits the
exact same wall but as a real syscall no storage setting can paper over. The first is fixable by
switching storage to `vfs` on local disk and telling it to drop ownership it cannot represent; the
second isn't fixable at all on lxplus, so the lxplus image is never built there — only pulled
already-built from a registry (see `image/lxplus/publish.sh`).

```bash
mkdir -p ~/.config/containers
cat > ~/.config/containers/storage.conf <<EOF
[storage]
driver = "vfs"
graphroot = "/tmp/$USER/containers"
runroot = "/tmp/$USER/run"

[storage.options.vfs]
ignore_chown_errors = "true"
EOF
rm -rf /tmp/$USER/containers
podman system reset -f
```

The `rm -rf` matters: podman records the driver in its database and refuses to switch while the
old overlay store is still there (`User-selected graph driver "vfs" overwritten by graph driver
"overlay" from database`). Check it took with `podman info | grep -A2 -i graphdriver`.

Then clone and symlink as above. `/tmp` is node-local and gets cleaned, so the image is re-pulled
whenever you land on a fresh node — the container home lives in `~/.sandbox-home` on AFS instead,
so the Claude Code login is not rebuilt with it.

## Use

```bash
cd ~/work/myproject
sandbox                 # interactive shell (builds/pulls the image if it's out of date)
sandbox make -j8        # run one command
sandbox --rebuild       # force a rebuild (local) / re-pull (lxplus), e.g. to pick up a new base image
```

Inside, CVMFS works as usual:

```bash
source /cvmfs/sft.cern.ch/lcg/views/LCG_106/x86_64-el9-gcc13-opt/setup.sh
```

## Adding software to the image

Anything installed via `dnf`/`npm`/etc. (as opposed to CVMFS) has to go in the Dockerfile for the
mode you use — `image/local/Dockerfile`, `image/lxplus/Dockerfile`, or both.

In local mode, `sandbox` builds directly from your checkout:

```bash
vim image/local/Dockerfile   # add e.g. `dnf -y install cmake` to the RUN chain
sandbox                      # picks up the change and rebuilds automatically
```

`sandbox` hashes every file under `image/local` and compares it to a label baked into the
last-built image; a mismatch (or no image at all) triggers a rebuild before the container starts.
`--rebuild` forces one unconditionally — useful to pull a fresh base image — and also works ahead
of a specific command: `sandbox --rebuild make -j8`. Existing containers aren't affected — only
the next `sandbox` invocation picks up the new image. The persistent home (`sandbox-home`) and
CVMFS cache survive a rebuild since they're separate Docker volumes.

lxplus can't build its own image (see [Install on lxplus](#install-on-lxplus)), so
`image/lxplus/Dockerfile` changes have to be published from a machine with real Docker/podman
privileges, then pulled:

```bash
vim image/lxplus/Dockerfile      # edit, off lxplus
docker login ghcr.io             # once, with a token that has write:packages
image/lxplus/publish.sh          # builds and pushes ghcr.io/tofitsch/sandbox:alma9-lxplus
```

Commit and push the Dockerfile change too, so `sandbox` on lxplus (which hashes its local
checkout the same way) knows to pull the new image instead of reusing a cached one. The first
time a package is published, its GHCR visibility defaults to private — set it to public in the
package's GitHub settings so lxplus can pull without credentials.

## Config

| Variable | Default |
|---|---|
| `SANDBOX_MODE` | `lxplus` on hosts named `lxplus*`, else `local` |
| `SANDBOX_CVMFS_REPOS` | `cvmfs-config.cern.ch sft.cern.ch sft-nightlies.cern.ch atlas.cern.ch atlas-condb.cern.ch atlas-nightlies.cern.ch unpacked.cern.ch` |
| `SANDBOX_IMAGE` | `sandbox:alma9`, or `ghcr.io/tofitsch/sandbox:alma9-lxplus` in lxplus mode |

Keep `cvmfs-config.cern.ch` first — the others need it to resolve. Override to add or drop repos:

```bash
SANDBOX_CVMFS_REPOS="cvmfs-config.cern.ch sft.cern.ch" sandbox   # skip atlas.cern.ch
```

In lxplus mode the repo list is only used to poke autofs on the host before the bind mount is
taken, since a repo that isn't mounted yet won't appear inside the container.

Reset the persistent home (drops the Claude login): `docker volume rm sandbox-home` in local
mode, `rm -rf ~/.sandbox-home` on lxplus.

## Caveats

Local mode's `--cap-add SYS_ADMIN` is required for the FUSE mount. This isolates your files; it
is not a hard security boundary against code you actively distrust.

Local mode assumes rootful Docker. If your host has `/cvmfs` via autofs but rootful Docker,
`SANDBOX_MODE=lxplus` gets you the bind mount, but the container then runs as real root and files
in `/work` will be owned by root.

On lxplus the `vfs` driver stores every layer in full, uncompressed, with no sharing between
them — the image costs several GB in `/tmp`. Check `df -h /tmp` if a pull dies partway. The home
on `~/.sandbox-home` counts against your AFS quota, and a long session needs a live AFS token.
