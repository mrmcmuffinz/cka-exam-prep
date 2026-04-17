FROM mcr.microsoft.com/devcontainers/base:trixie

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        bubblewrap \
        socat \
        vim \
        python3-pip \
    && rm -rf /var/lib/apt/lists/*
RUN python3 -m pip install semgrep --break-system-packages

COPY fix-perms-entrypoint.sh /usr/local/bin/fix-perms-entrypoint.sh
RUN chmod +x /usr/local/bin/fix-perms-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/fix-perms-entrypoint.sh"]
CMD ["sleep", "infinity"]