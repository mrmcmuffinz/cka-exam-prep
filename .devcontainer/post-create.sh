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

# HACK: Manually remove GitHub Copilot extensions
# This is needed because VS Code's extensions.allowed setting has known bugs:
# - Bug #240834: extensions.allowed does not prevent installation
# - Bug #10800: extensions.allowed breaks dev containers when deployed via policy
# Once these are fixed upstream, this block can be removed.
# Track: https://github.com/microsoft/vscode/issues/240834
#        https://github.com/microsoft/vscode-remote-release/issues/10800

echo "==> Removing GitHub Copilot extensions (workaround for VS Code bug #240834)..."

EXTENSIONS_DIR="${HOME}/.vscode-server/extensions"

if [ -d "${EXTENSIONS_DIR}" ]; then
  # Remove Copilot extensions by exact ID prefix (more precise than github*)
  find "${EXTENSIONS_DIR}" -maxdepth 1 -type d \( \
    -name "github.copilot-*" -o \
    -name "github.copilot-chat-*" \
  \) -exec rm -rf {} + 2>/dev/null || true

  echo "   Copilot extensions removed (if present)"
else
  echo "   Extensions directory not found yet (will be created on first VS Code connection)"
fi