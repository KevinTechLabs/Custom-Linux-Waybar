#!/usr/bin/env bash
# ☢ Power menu — fullscreen reactor control (rofi). Arrows / Enter, Esc to abort.

tile() { printf "%s\n<span size='12pt' weight='bold'>%s</span>" "$1" "$2"; }

if command -v rofi >/dev/null; then
  up=$(uptime -p | sed 's/up //; s/ hours\?/h/; s/ minutes\?/m/; s/ days\?/d/; s/,//g')
  opts="$(tile "󰌾" LOCK)|$(tile "󰤄" SLEEP)|$(tile "󰍃" "LOG OUT")|$(tile "󰜉" REBOOT)|$(tile "󰐥" SHUTDOWN)"
  choice=$(printf '%s' "$opts" | rofi -dmenu -sep '|' -eh 2 -markup-rows -i \
    -no-show-icons -u 4 -selected-row 0 \
    -p "☢  REACTOR SHUTDOWN CONTROL" \
    -mesg "core online for $up" \
    -theme ~/.config/rofi/power.rasi)
else
  choice=$(printf 'LOCK\nSLEEP\nLOG OUT\nREBOOT\nSHUTDOWN' | wofi --dmenu -p "POWER" --width 320 --height 260)
fi

case $choice in
  *LOCK*)       hyprlock 2>/dev/null || loginctl lock-session ;;
  *SLEEP*)      systemctl suspend ;;
  *"LOG OUT"*)  hyprctl dispatch "hl.dsp.exit()" 2>&1 | grep -qi error && \
                { hyprctl dispatch exit 2>&1 | grep -qi error && loginctl terminate-session "$XDG_SESSION_ID"; } ;;
  *REBOOT*)     systemctl reboot ;;
  *SHUTDOWN*)   systemctl poweroff ;;
esac
