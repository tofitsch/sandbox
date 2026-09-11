# sandbox

Provided as-is, with no guarantee of safety or fitness for any purpose. Use at your own risk.

```
Usage: sandbox [options] [command...]

Drops you into a disposable AlmaLinux 9 container that behaves roughly like
lxplus: CVMFS available, current directory as the workdir, your real $HOME
invisible. With no command, starts an interactive shell; otherwise runs the
given command and exits.

Options:
  -r SRC DST    mount host directory SRC read-only at DST in the container
  -w SRC DST    mount host directory SRC read-write at DST in the container
                (either may be repeated, and appear anywhere in the arguments)
  -r            bare, with no SRC/DST: mount $PWD at /work read-only instead
                of the default read-write (must be the last argument)
  --rebuild     force a rebuild (local mode) or re-pull (lxplus mode)
  -h, --help    show this help and exit
```

**It works differently depending on where you run it.** On a normal (`local`) machine, `sandbox`
builds its own image straight from this repo. On `lxplus`, it never builds — rootless podman
there can't (see [Install on lxplus](#install-on-lxplus)) — so it instead pulls a pre-built image:
[`ghcr.io/tofitsch/sandbox:alma9-lxplus`](https://github.com/users/tofitsch/packages/container/package/sandbox).

- **Workdir** — `$PWD` is mounted at `/work`. Files you create there stay owned by you.
- **Persistent home** — `/home/$USER` survives restarts, so a Claude Code login is done once.
- **CVMFS** — mounted at container start, or passed through from the host on lxplus.
- **Shell init** — `bashrc.sh` in this repo is mounted read-only and sourced at every start, so
  edits take effect on the next `sandbox` with no rebuild.
- **Editor config** — `~/.rootrc`, `~/.config/nvim`, and `~/.config/ranger` from the host are
  mounted read-only into the container home, if present. Neovim and ranger are installed in the
  image.
- **Git config** — `~/.gitconfig` from the host is mounted read-only into the container home, if
  present.
- **SSH** — the host's `ssh-agent` socket is forwarded in, so `git@github.com:...`-style remotes
  work inside the container. The private key itself is never mounted or copied — only the live
  agent socket, so the container can ask the host to sign, nothing more. If no agent is running on
  the host, `sandbox` starts one (persisted at `~/.ssh/sandbox-agent.env` so it's reused by the
  next `sandbox` run); if that agent has no key loaded, `sandbox` explains it's needed for git
  over SSH and prompts for a key path (default `~/.ssh/id_ed25519`, or `no` to skip) and runs
  `ssh-add` on it before starting the container.
- **Claude Code rules** — `CLAUDE.md` in this repo is mounted read-only as the container's global
  `~/.claude/CLAUDE.md`, so it applies to Claude Code for any project run inside the sandbox.

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

`docker` on lxplus is rootless podman with no `/etc/subuid` range, so it can only pull images,
never build them — the lxplus image is always pulled pre-built (see
[Adding software](#adding-software-to-the-image)). It also needs `vfs` storage to tolerate file
ownership it can't remap:

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
rm -rf /tmp/$USER/containers   # old store blocks the driver switch otherwise
podman system reset -f
```

Then clone and symlink as above ([Install](#install)). `/tmp` is node-local, so the image re-pulls
on a fresh node; the persistent home lives in `~/.sandbox-home` on AFS instead.

You'll see `Emulate Docker CLI using podman...` on every `docker` call — cosmetic, safe to ignore.

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

First-time setup on whichever machine you publish from (once — it adds the `packages` scope to
your existing `gh` login and hands the resulting token to Docker):

```bash
gh auth refresh -h github.com -s write:packages
gh auth token | docker login ghcr.io -u tofitsch --password-stdin
```

Then, for every Dockerfile change:

```bash
vim image/lxplus/Dockerfile      # edit, off lxplus
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
