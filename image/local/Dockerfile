FROM almalinux:9

RUN dnf -y install epel-release && \
    dnf -y install --allowerasing git wget curl vim neovim less tar which procps-ng \
        util-linux findutils make gcc gcc-c++ python3 python3-pip fuse fuse3 man-db ranger && \
    dnf -y install https://ecsft.cern.ch/dist/cvmfs/cvmfs-release/cvmfs-release-latest.noarch.rpm && \
    dnf -y install cvmfs cvmfs-config-default && \
    dnf -y module enable nodejs:20 && dnf -y install nodejs npm && \
    npm install -g @anthropic-ai/claude-code && \
    curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR=/usr/local/bin UV_UNMANAGED_INSTALL=1 sh && \
    curl -fsSL https://pixi.sh/install.sh | env PIXI_HOME=/usr/local PIXI_NO_PATH_UPDATE=1 sh && \
    echo user_allow_other >> /etc/fuse.conf && \
    dnf clean all && npm cache clean --force

ENV DISABLE_AUTOUPDATER=1

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
