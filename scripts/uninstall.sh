#!/usr/bin/env bash
# ☢ REACTOR — uninstaller
# Removes the links this repo created and the small lines it added to your
# fish / kitty / Hyprland configs. Backups (*.backup-*) are left in place.
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
CFG="$HOME/.config"

# links that point into this repo
while IFS= read -r -d '' l; do
  [[ $(readlink "$l") == "$ROOT_DIR"/* ]] && rm "$l" && echo "removed ${l/#$HOME/~}"
done < <(find "$CFG" -type l -print0 2>/dev/null)

# lines we appended
sed -i -e '/reactor\/reactor.fish/d' -e '/^# ☢ REACTOR/d' \
       -e 's/^\([[:space:]]*\)# \(fastfetch.*\)  # disabled by REACTOR$/\1\2/' "$CFG/fish/config.fish" 2>/dev/null || true
sed -i -e '/reactor-kitty.conf/d' -e '/^# ☢ REACTOR/d' "$CFG/kitty/kitty.conf" 2>/dev/null || true
sed -i -e '/hypr\/reactor.lua/d' -e '/^-- ☢ REACTOR/d' "$CFG/hypr/hyprland.lua" 2>/dev/null || true
sed -i -e '/hypr\/reactor.conf/d' -e '/^# ☢ REACTOR/d' "$CFG/hypr/hyprland.conf" 2>/dev/null || true
rm -f "$CFG/hypr/reactor.lua" "$CFG/hypr/reactor.conf"

eww -c "$CFG/eww/reactor" kill >/dev/null 2>&1 || true
echo
echo "☢ REACTOR removed. Your *.backup-* files are untouched — restore any you want."
echo "  (optional) sudo rm /etc/tmpfiles.d/reactor-rapl.conf"
