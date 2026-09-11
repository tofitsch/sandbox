#!/usr/bin/env bash
set -e

# Builds and pushes the lxplus sandbox image. Run this on a machine with real
# Docker/podman privileges -- lxplus's rootless podman has no subuid range, so it
# can't build images that ship setuid/setgid files (e.g. openssh's ssh-keysign).
# lxplus only ever pulls what this script publishes; see `sandbox`.
IMG=${SANDBOX_IMAGE:-ghcr.io/tofitsch/sandbox:alma9-lxplus}
DIR=$(dirname "$(readlink -f "$0")")
IMGDIR=$(dirname "$DIR")

HASH=$(find "$DIR" "$IMGDIR/common" -type f -exec sha256sum {} + | sort | sha256sum | cut -d' ' -f1)

docker build --pull --label sandbox.contenthash="$HASH" -t "$IMG" -f "$DIR/Dockerfile" "$IMGDIR"
docker push "$IMG"
