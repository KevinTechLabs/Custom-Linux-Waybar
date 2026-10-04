#!/usr/bin/env bash
# ☢ Screen on/off that works on both classic and Lua (0.55+) Hyprland dispatch.
# usage: reactor-dpms.sh on|off
s=${1:-on}
out=$(hyprctl dispatch dpms "$s" 2>&1)
if [[ $out == *rror* ]]; then
  hyprctl dispatch "hl.dsp.dpms({ action = '$s' })" >/dev/null 2>&1
fi
