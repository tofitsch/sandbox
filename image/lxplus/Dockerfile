FROM almalinux:9

# No cvmfs client here: on lxplus /cvmfs is already mounted on the host and is
# bind-mounted into the container by the launcher.
RUN dnf -y install epel-release && \
    dnf -y install --setopt=install_weak_deps=False git wget vim neovim less tar which procps-ng \
        util-linux findutils make gcc gcc-c++ python3 python3-pip man-db ranger && \
    dnf -y module enable nodejs:20 && dnf -y install nodejs npm && \
    npm install -g @anthropic-ai/claude-code && \
    dnf clean all && npm cache clean --force

ENV DISABLE_AUTOUPDATER=1

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
