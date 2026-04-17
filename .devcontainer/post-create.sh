#!/usr/bin/env bash
# post-create.sh — runs once after the dev container is built.

set -euo pipefail

# Install global Claude Code context
mkdir -p /home/vscode/.claude 2>/dev/null || true
if [ -f .claude/global-CLAUDE.md ]; then
  cp .claude/global-CLAUDE.md ~/.claude/CLAUDE.md
  echo "==> Claude Code global context installed"
fi

# Symlink .claude.json into the persisted volume
if [ -f /home/vscode/.claude/claude.json ]; then
  ln -sf /home/vscode/.claude/claude.json /home/vscode/.claude.json
fi

curl -fsSL https://claude.ai/install.sh | bash

echo "==> Fixing workspace permissions..."
sudo chown -R vscode:vscode /workspaces 2>/dev/null || true

echo "==> Dev container ready."
