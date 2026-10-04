#!/usr/bin/env bash
# ☢ Switch workspace on both new (Lua config, 0.5x+) and classic Hyprland.
# usage: ws-go.sh 3 | ws-go.sh e+1 | ws-go.sh e-1

t=${1:?workspace}
if [[ $t =~ ^-?[0-9]+$ ]]; then lua="hl.dsp.focus({ workspace = $t })"
else                             lua="hl.dsp.focus({ workspace = '$t' })"; fi

out=$(hyprctl dispatch "$lua" 2>&1)
if [[ $out == *error* || $out == *rror* ]]; then
  hyprctl dispatch workspace "$t" >/dev/null 2>&1   # classic syntax fallback
fi
