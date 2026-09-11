FROM almalinux:9

# No cvmfs client here: on lxplus /cvmfs is already mounted on the host and is
# bind-mounted into the container by the launcher.
RUN dnf -y install epel-release && \
    dnf -y install --setopt=install_weak_deps=False --allowerasing git wget curl vim neovim less tar which procps-ng \
        util-linux findutils make gcc gcc-c++ python3 python3-pip man-db ranger zathura feh && \
    dnf -y module enable nodejs:20 && dnf -y install nodejs npm && \
    npm install -g @anthropic-ai/claude-code && \
    curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR=/usr/local/bin UV_UNMANAGED_INSTALL=1 sh && \
    curl -fsSL https://pixi.sh/install.sh | env PIXI_HOME=/usr/local PIXI_NO_PATH_UPDATE=1 sh && \
    dnf clean all && npm cache clean --force

ENV DISABLE_AUTOUPDATER=1

COPY common/osc52.vim /usr/share/nvim/osc52.vim
RUN cat /usr/share/nvim/osc52.vim >> /usr/share/nvim/sysinit.vim

COPY lxplus/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
