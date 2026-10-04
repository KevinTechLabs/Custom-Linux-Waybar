#!/usr/bin/env bash
# ☢ REACTOR — pull the latest version and re-run the installer.
set -euo pipefail
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
git -C "$ROOT_DIR" pull --ff-only
bash "$ROOT_DIR/scripts/install.sh" "$@"
