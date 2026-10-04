#!/usr/bin/env bash
# ☢ Pending updates for the REACTOR sidebar.
#   updates.sh           -> JSON (cached; refreshes in the background every 15 min)
#   updates.sh refresh   -> force a fresh check now
#   updates.sh run       -> open kitty and install updates, then re-check
#
# Repo updates use `checkupdates` (pacman-contrib) — safe, doesn't touch your
# real package database. AUR updates use paru or yay if you have one.

CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/reactor-updates.json"
LOCK="${XDG_RUNTIME_DIR:-/tmp}/reactor-updates.lock"
MAX_AGE=900   # seconds

check() {
  exec 8>"$LOCK"; flock -n 8 || return 0       # one check at a time
  local repo=0 aur=0 err="" list
  if command -v checkupdates >/dev/null; then
    list=$(checkupdates 2>/dev/null)
    repo=$(grep -c . <<< "$list")
  else
    err="install pacman-contrib"
  fi
  if command -v paru >/dev/null; then
    aur=$(paru -Qua 2>/dev/null | grep -c .)
  elif command -v yay >/dev/null; then
    aur=$(yay -Qua 2>/dev/null | grep -c .)
  fi
  mkdir -p "$(dirname "$CACHE")"
  printf '{"total":%d,"repo":%d,"aur":%d,"checked":"%s","err":"%s"}\n' \
    $((repo + aur)) "$repo" "$aur" "$(date +%H:%M)" "$err" > "$CACHE.tmp" && mv "$CACHE.tmp" "$CACHE"
}

case $1 in
  refresh) check; exit 0 ;;
  run)
    if command -v paru >/dev/null; then cmd="paru -Syu"
    elif command -v yay >/dev/null; then cmd="yay -Syu"
    else cmd="sudo pacman -Syu"; fi
    setsid -f kitty --class reactor-update -e bash -c "
      echo -e '\e[38;2;57;255;20m☢ REACTOR MAINTENANCE — $cmd\e[0m'; echo
      $cmd
      echo; echo -e '\e[38;2;31;143;11mre-checking…\e[0m'
      '$0' refresh
      read -rp 'done · press enter to close'"
    "$HOME/.config/eww/reactor/scripts/toggle.sh"   # slide the sidebar away
    exit 0 ;;
esac

# default: print cached result, refresh in the background when stale
age=$(( $(date +%s) - $(stat -c %Y "$CACHE" 2>/dev/null || echo 0) ))
if (( age > MAX_AGE )); then
  ( check >/dev/null 2>&1 & ) 9>&-
fi
cat "$CACHE" 2>/dev/null || echo '{"total":-1,"repo":0,"aur":0,"checked":"--","err":""}'
