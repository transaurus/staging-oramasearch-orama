#!/usr/bin/env bash
set -euo pipefail

# Setup script for oramasearch/orama
# Docusaurus 3.9.1 sandbox at sandboxes/plugin-docusaurus-v3-sandbox
# pnpm@10.9.0 monorepo, Node >= 20 required

REPO_URL="https://github.com/oramasearch/orama"
REPO_DIR="source-repo"
DOCUSAURUS_PATH="sandboxes/plugin-docusaurus-v3-sandbox"
PLUGIN_PACKAGE="@orama/plugin-docusaurus-v3"

export N_PREFIX="${HOME}/.n"
export PATH="${N_PREFIX}/bin:${HOME}/.local/bin:/usr/local/bin:/usr/bin:/bin"

# Ensure Node 20+
NODE_MAJOR=$(node --version 2>/dev/null | sed 's/v\([0-9]*\).*/\1/' || echo "0")
if [ "$NODE_MAJOR" -lt 20 ]; then
    echo "Node $NODE_MAJOR found, need 20+. Installing via n..."
    if ! command -v n >/dev/null 2>&1; then
        curl -fsSL https://raw.githubusercontent.com/tj/n/master/bin/n -o /tmp/n
        bash /tmp/n 20
    else
        n 20
    fi
    export PATH="${HOME}/.n/bin:$PATH"
fi

echo "Node version: $(node --version)"
echo "npm version: $(npm --version)"

# Install pnpm via corepack
export COREPACK_ENABLE_STRICT=0
corepack enable pnpm
corepack prepare pnpm@10.9.0 --activate
export PATH="${HOME}/.local/share/pnpm:${HOME}/.pnpm:$PATH"

echo "pnpm version: $(pnpm --version)"

# Clone repo
if [ ! -d "$REPO_DIR" ]; then
    git clone --depth=1 "$REPO_URL" "$REPO_DIR"
else
    echo "Repo already cloned, skipping..."
fi

cd "$REPO_DIR"

# Disable corepack strict mode for the repo
export COREPACK_ENABLE_STRICT=0

# Install all workspace dependencies
echo "[INFO] Installing all workspace dependencies..."
pnpm install --frozen-lockfile

# Build plugin-docusaurus-v3 and all its workspace dependencies
echo "[INFO] Building plugin-docusaurus-v3 and workspace deps..."
pnpm --filter "${PLUGIN_PACKAGE}..." run build

# Run write-translations from the sandbox
echo "[INFO] Running write-translations..."
cd "$DOCUSAURUS_PATH"
pnpm run write-translations

echo "[SUCCESS] write-translations completed!"
