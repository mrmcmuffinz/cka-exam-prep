#!/bin/sh
# fix-perms-entrypoint.sh
# Ensures the /vscode volume and workspace bind mount are owned by vscode user.
# Runs as root at container start, before VS Code Server launches.

if [ -d /vscode ]; then
  chown -R vscode:vscode /vscode
fi

if [ -d /workspaces ]; then
  chown -R vscode:vscode /workspaces
fi

if [ -d /home/vscode/.claude ]; then
  chown -R vscode:vscode /home/vscode/.claude
fi

exec "$@"