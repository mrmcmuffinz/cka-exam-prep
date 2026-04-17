FROM mcr.microsoft.com/devcontainers/base:trixie

RUN apt-get update && \
    apt-get install -y --no-install-recommends vim  && \
    rm -rf /var/lib/apt/lists/*

COPY fix-perms-entrypoint.sh /usr/local/bin/fix-perms-entrypoint.sh
RUN chmod +x /usr/local/bin/fix-perms-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/fix-perms-entrypoint.sh"]
CMD ["sleep", "infinity"]