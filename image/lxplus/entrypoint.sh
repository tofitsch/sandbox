#!/bin/bash
# lxplus mode: rootless podman without a subuid range, so uid 0 in the container
# is the only mapped id and it *is* the host user. Nothing to create, nothing to
# drop to -- files written to /work already come out owned by you on the host.
# /cvmfs is bind-mounted from the host, so there is no mount to perform either.
set -e

H=/home/$HOST_USER
mkdir -p "$H"

# --- shell init (re-read from the host file on every start) ---
echo '. /etc/bashrc; [ -f /etc/bashrc_sandbox ] && . /etc/bashrc_sandbox' > "$H/.bashrc"
cp "$H/.bashrc" "$H/.bash_profile"

# --- ranger config (re-read from the host files on every start; bookmarks/tagged
# stay in the container's own confdir since ranger needs to write those itself) ---
if [ -d "$H/.config/ranger-host" ]; then
  mkdir -p "$H/.config/ranger"
  for f in rc.conf rifle.conf scope.sh; do
    [ -f "$H/.config/ranger-host/$f" ] && cp "$H/.config/ranger-host/$f" "$H/.config/ranger/$f"
  done
fi

export HOME="$H" USER="$HOST_USER" LOGNAME="$HOST_USER"
cd /work

if [ $# -eq 0 ]; then
  exec bash -i
else
  exec bash -lc "$*"
fi
