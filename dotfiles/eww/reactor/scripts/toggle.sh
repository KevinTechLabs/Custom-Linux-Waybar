#!/usr/bin/env bash
# ☢ Show / hide the REACTOR sidebar (Super+Z). Hyprland animates the slide.
C="$HOME/.config/eww/reactor"
E=(eww -c "$C")
RUN="${XDG_RUNTIME_DIR:-/tmp}"
LOCK="$RUN/reactor-eww.lock"
STATE="$RUN/reactor-eww.open"

exec 9>"$LOCK"; flock -n 9 || exit 0

if ! "${E[@]}" ping >/dev/null 2>&1; then
  "${E[@]}" daemon 9>&-                   # don't let the daemon inherit the lock
  rm -f "$STATE"
  for _ in $(seq 1 30); do "${E[@]}" ping >/dev/null 2>&1 && break; sleep 0.1; done
fi

is_open() {
  local w
  if w=$("${E[@]}" active-windows 2>/dev/null); then
    grep -q sidebar <<< "$w"; return
  fi
  [[ -f $STATE ]]
}

if is_open; then
  "${E[@]}" close sidebar; rm -f "$STATE"
else
  "${E[@]}" open sidebar;  touch "$STATE"
fi
