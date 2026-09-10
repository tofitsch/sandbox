# sandbox

`sandbox` drops you into a disposable AlmaLinux 9 container that behaves roughly like lxplus:
CVMFS mounted, current directory as the workdir, your real `$HOME` invisible.

- **Workdir** — `$PWD` is mounted at `/work`. Files you create there stay owned by you.
- **Persistent home** — `/home/$USER` is the Docker volume `sandbox-home`, so a Claude Code login
  survives restarts. You log in once.
- **CVMFS** — mounted at container start, cache kept in the volume `sandbox-cvmfs`.
- **Shell init** — `bashrc.sh` in this repo is mounted read-only and sourced at every start, so
  edits take effect on the next `sandbox` with no rebuild.
- **Editor config** — `~/.rootrc` and `~/.config/nvim` from the host are mounted read-only into
  the container home, if present. Neovim is installed in the image.
- **Claude Code rules** — `CLAUDE.md` in this repo is mounted read-only as the container's global
  `~/.claude/CLAUDE.md`, so it applies to Claude Code for any project run inside the sandbox.

## Layout

```
sandbox               # the launcher, goes on your PATH
bashrc.sh             # sourced in every container shell — put your aliases here
CLAUDE.md             # global Claude Code rules for every project run inside the sandbox
image/Dockerfile      # AlmaLinux 9 + CVMFS + Node + Claude Code
image/entrypoint.sh   # mounts CVMFS, matches your UID, drops privileges
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

## Use

```bash
cd ~/work/myproject
sandbox                 # interactive shell (builds/rebuilds the image if image/ changed)
sandbox make -j8        # run one command
sandbox --rebuild       # force a rebuild, e.g. to pick up a new base image
```

Inside, CVMFS works as usual:

```bash
source /cvmfs/sft.cern.ch/lcg/views/LCG_106/x86_64-el9-gcc13-opt/setup.sh
```

## Adding software to the image

Anything installed via `dnf`/`npm`/etc. (as opposed to CVMFS) has to go in `image/Dockerfile`.

```bash
vim image/Dockerfile   # add e.g. `dnf -y install cmake` to the RUN chain
sandbox                 # picks up the change and rebuilds automatically
```

`sandbox` hashes every file under `image/` and compares it to a label baked into the last-built
image; a mismatch (or no image at all) triggers a rebuild before the container starts. `--rebuild`
forces one unconditionally — useful to pull a fresh base image — and also works ahead of a
specific command: `sandbox --rebuild make -j8`. Existing containers aren't affected — only the
next `sandbox` invocation picks up the new image. The persistent home (`sandbox-home`) and CVMFS
cache survive a rebuild since they're separate Docker volumes.

## Config

| Variable | Default |
|---|---|
| `SANDBOX_CVMFS_REPOS` | `cvmfs-config.cern.ch sft.cern.ch sft-nightlies.cern.ch atlas.cern.ch atlas-condb.cern.ch atlas-nightlies.cern.ch unpacked.cern.ch` |
| `SANDBOX_IMAGE` | `sandbox:alma9` |

Keep `cvmfs-config.cern.ch` first — the others need it to resolve. Override to add or drop repos:

```bash
SANDBOX_CVMFS_REPOS="cvmfs-config.cern.ch sft.cern.ch" sandbox   # skip atlas.cern.ch
```

Reset the persistent home (drops the Claude login): `docker volume rm sandbox-home`

## Caveats

`--cap-add SYS_ADMIN` is required for the FUSE mount. This isolates your files; it is not a hard
security boundary against code you actively distrust.

If your host already has `/cvmfs` via autofs, swap the CVMFS lines in the launcher for
`-v /cvmfs:/cvmfs:ro,rslave` and drop `--cap-add SYS_ADMIN --device /dev/fuse`.

Assumes rootful Docker. Rootless needs different UID mapping.
