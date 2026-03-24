#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/oramasearch/orama"
BRANCH="main"
REPO_DIR="source-repo"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Clone (skip if already exists) ---
if [ ! -d "$REPO_DIR" ]; then
    git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$REPO_DIR"
fi

cd "$REPO_DIR"

# --- Node version ---
# oramasearch/orama requires Node >= 20. .nvmrc specifies 24.5
# Use nvm to install and activate the correct version
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
if [ -s "$NVM_DIR/nvm.sh" ]; then
    # shellcheck source=/dev/null
    source "$NVM_DIR/nvm.sh"
    nvm install 24 || nvm install 20
    nvm use 24 2>/dev/null || nvm use 20 || true
fi

NODE_MAJOR=$(node --version | sed 's/v//' | cut -d. -f1)
if [ "$NODE_MAJOR" -lt 20 ]; then
    echo "[ERROR] Node $NODE_MAJOR detected, but orama requires Node >= 20."
    exit 1
fi
echo "[INFO] Using $(node --version)"

# --- Package manager: pnpm ---
# Root package.json specifies pnpm@10.9.0
# Enable corepack to get the exact version
if ! command -v pnpm &>/dev/null; then
    npm install -g pnpm@10 || corepack enable && corepack prepare pnpm@10.9.0 --activate
fi

# Try to activate exact version via corepack (may fail gracefully)
corepack enable 2>/dev/null || true
corepack prepare pnpm@10.9.0 --activate 2>/dev/null || true

echo "[INFO] Using pnpm $(pnpm --version)"

# --- Install all workspace dependencies ---
pnpm install --frozen-lockfile

# --- Build workspace packages required by the sandbox ---
# sandbox/plugin-docusaurus-v3-sandbox depends on @orama/plugin-docusaurus-v3 (workspace:*)
# Build order (from turbo.json dependency graph):
#   @orama/stemmers -> @orama/orama -> @orama/plugin-analytics, @orama/plugin-parsedoc -> @orama/plugin-docusaurus-v3
echo "[INFO] Building workspace dependencies for plugin-docusaurus-v3..."
pnpm --filter @orama/stemmers... build
pnpm --filter @orama/orama... build
pnpm --filter @orama/plugin-analytics build
pnpm --filter @orama/plugin-parsedoc build
pnpm --filter @orama/plugin-docusaurus-v3 build

# --- Apply fixes.json if present ---
FIXES_JSON="$SCRIPT_DIR/fixes.json"
if [ -f "$FIXES_JSON" ]; then
    echo "[INFO] Applying content fixes..."
    node -e "
    const fs = require('fs');
    const path = require('path');
    const fixes = JSON.parse(fs.readFileSync('$FIXES_JSON', 'utf8'));
    for (const [file, ops] of Object.entries(fixes.fixes || {})) {
        if (!fs.existsSync(file)) { console.log('  skip (not found):', file); continue; }
        let content = fs.readFileSync(file, 'utf8');
        for (const op of ops) {
            if (op.type === 'replace' && content.includes(op.find)) {
                content = content.split(op.find).join(op.replace || '');
                console.log('  fixed:', file, '-', op.comment || '');
            }
        }
        fs.writeFileSync(file, content);
    }
    for (const [file, cfg] of Object.entries(fixes.newFiles || {})) {
        const c = typeof cfg === 'string' ? cfg : cfg.content;
        fs.mkdirSync(path.dirname(file), {recursive: true});
        fs.writeFileSync(file, c);
        console.log('  created:', file);
    }
    "
fi

echo "[DONE] Repository is ready for docusaurus commands."
