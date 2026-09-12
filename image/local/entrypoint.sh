#!/bin/bash
# Runs as root: mount CVMFS, create a user matching the host UID, then drop privileges.
set -e

H=/home/$HOST_USER
getent passwd "$HOST_UID" >/dev/null || {
  groupadd -g "$HOST_GID" "$HOST_USER"
  useradd -u "$HOST_UID" -g "$HOST_GID" -M -d "$H" -s /bin/bash "$HOST_USER"
}
mkdir -p "$H" && chown "$HOST_UID:$HOST_GID" "$H"

# --- CVMFS ---
cat > /etc/cvmfs/default.local <<CFG
CVMFS_CLIENT_PROFILE=single
CVMFS_HTTP_PROXY=DIRECT
CVMFS_CACHE_BASE=/var/lib/cvmfs
CVMFS_QUOTA_LIMIT=20000
CFG
mkdir -p /var/lib/cvmfs && chown -R cvmfs:cvmfs /var/lib/cvmfs
for r in $CVMFS_REPOS; do
  mkdir -p "/cvmfs/$r"
  mount -t cvmfs "$r" "/cvmfs/$r" || echo "warning: /cvmfs/$r not mounted" >&2
done

# --- shell init (re-read from the host file on every start) ---
echo '. /etc/bashrc; [ -f /etc/bashrc_sandbox ] && . /etc/bashrc_sandbox' > "$H/.bashrc"
cp "$H/.bashrc" "$H/.bash_profile"
chown "$HOST_UID:$HOST_GID" "$H/.bashrc" "$H/.bash_profile"

# --- ranger config (re-read from the host files on every start; bookmarks/tagged
# stay in the container's own confdir since ranger needs to write those itself) ---
if [ -d "$H/.config/ranger-host" ]; then
  mkdir -p "$H/.config/ranger"
  for f in rc.conf rifle.conf scope.sh; do
    [ -f "$H/.config/ranger-host/$f" ] && cp "$H/.config/ranger-host/$f" "$H/.config/ranger/$f"
  done
  chown -R "$HOST_UID:$HOST_GID" "$H/.config/ranger"
fi

cd /work
run=(setpriv --reuid "$HOST_UID" --regid "$HOST_GID" --init-groups
     env HOME="$H" USER="$HOST_USER" LOGNAME="$HOST_USER")

if [ $# -eq 0 ]; then
  exec "${run[@]}" bash -i
else
  exec "${run[@]}" bash -lc "$*"
fi
