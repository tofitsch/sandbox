FROM almalinux:9

RUN dnf -y install epel-release && \
    dnf -y install --allowerasing git curl wget vim less tar which procps-ng \
        util-linux findutils make gcc gcc-c++ python3 python3-pip fuse && \
    dnf -y install https://ecsft.cern.ch/dist/cvmfs/cvmfs-release/cvmfs-release-latest.noarch.rpm && \
    dnf -y install cvmfs cvmfs-config-default && \
    dnf -y module enable nodejs:20 && dnf -y install nodejs npm && \
    npm install -g @anthropic-ai/claude-code && \
    echo user_allow_other >> /etc/fuse.conf && \
    dnf clean all && npm cache clean --force

ENV DISABLE_AUTOUPDATER=1

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
