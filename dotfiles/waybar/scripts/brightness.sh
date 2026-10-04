#!/usr/bin/env bash
# ☢ Brightness meter for Waybar (laptop):  󰃠 [██████░░░░] 60%
#   brightness.sh [cells]   -> JSON
#   brightness.sh up|down   -> change by 5% and refresh the bar
# Needs brightnessctl.

DIM="#1f8f0b"
cells() { local s="" k; for ((k = 0; k < $2; k++)); do s+=$1; done; printf '%s' "$s"; }

case $1 in
  up)   brightnessctl -q set 5%+;            pkill -RTMIN+11 waybar; exit 0 ;;
  down) brightnessctl -q -n 1 set 5%-;       pkill -RTMIN+11 waybar; exit 0 ;;   # -n 1: never fully black
esac

CELLS=${1:-10}
if ! command -v brightnessctl >/dev/null; then
  echo '{"text":"󰃠 N/A","class":"missing","tooltip":"install brightnessctl"}'; exit 0
fi
cur=$(brightnessctl get 2>/dev/null); max=$(brightnessctl max 2>/dev/null)
if [[ -z $cur || -z $max || $max == 0 ]]; then
  echo '{"text":"󰃠 N/A","class":"missing","tooltip":"no backlight found"}'; exit 0
fi
pct=$(( (cur * 100 + max / 2) / max ))
n=$(( (pct * CELLS + 99) / 100 )); (( n > CELLS )) && n=$CELLS
icon="󰃞"; (( pct >= 34 )) && icon="󰃟"; (( pct >= 67 )) && icon="󰃠"
printf '{"text":"%s <span foreground=\\"%s\\">[</span>%s<span foreground=\\"%s\\">%s]</span> %s%%","class":"normal","tooltip":"Brightness · %s%%\\nscroll to adjust"}\n' \
  "$icon" "$DIM" "$(cells █ "$n")" "$DIM" "$(cells ░ $((CELLS - n)))" "$pct" "$pct"
