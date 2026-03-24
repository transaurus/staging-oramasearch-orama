#!/usr/bin/env bash
set -euo pipefail

# Rebuild script for oramasearch/orama
# Runs on an existing source tree (no clone). Installs deps, builds workspace packages, builds site.
# Expected to run from: source-repo/sandboxes/plugin-docusaurus-v3-sandbox/

# Navigate to repo root (two levels up from docusaurusRoot)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# When run from docusaurusRoot, we need to go to repo root
cd "$(pwd)"
# Go up to repo root (plugin-docusaurus-v3-sandbox -> sandboxes -> repo root)
REPO_ROOT="$(cd "$(pwd)/../../" && pwd 2>/dev/null || pwd)"

# Try to go to repo root if we're in the docusaurus sandbox
if [ -f "../../pnpm-workspace.yaml" ]; then
    cd ../..
    REPO_ROOT="$(pwd)"
elif [ -f "../../../pnpm-workspace.yaml" ]; then
    cd ../../..
    REPO_ROOT="$(pwd)"
fi

echo "[INFO] Working from: $REPO_ROOT"

# --- Node version ---
# oramasearch/orama requires Node >= 20. .nvmrc specifies 24.5
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
if [ -s "$NVM_DIR/nvm.sh" ]; then
    # shellcheck source=/dev/null
    source "$NVM_DIR/nvm.sh"
    nvm use 24 2>/dev/null || nvm use 20 2>/dev/null || true
fi

NODE_MAJOR=$(node --version | sed 's/v//' | cut -d. -f1)
if [ "$NODE_MAJOR" -lt 20 ]; then
    echo "[ERROR] Node $NODE_MAJOR detected, but orama requires Node >= 20."
    exit 1
fi
echo "[INFO] Using $(node --version)"

# --- Package manager: pnpm ---
if ! command -v pnpm &>/dev/null; then
    npm install -g pnpm@10
fi
corepack enable 2>/dev/null || true

echo "[INFO] Using pnpm $(pnpm --version)"

# --- Install all workspace dependencies ---
pnpm install --frozen-lockfile

# --- Build workspace packages required by the sandbox ---
echo "[INFO] Building workspace dependencies for plugin-docusaurus-v3..."
pnpm --filter @orama/stemmers... build
pnpm --filter @orama/orama... build
pnpm --filter @orama/plugin-analytics build
pnpm --filter @orama/plugin-parsedoc build
pnpm --filter @orama/plugin-docusaurus-v3 build

# --- Build Docusaurus site ---
cd sandboxes/plugin-docusaurus-v3-sandbox
echo "[INFO] Building Docusaurus site..."
pnpm build:docs

echo "[DONE] Build complete."
