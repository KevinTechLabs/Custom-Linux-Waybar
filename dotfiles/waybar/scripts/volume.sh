#!/usr/bin/env bash
# ☢ Volume meter for Waybar:  󰕾 [██████░░░░░░░░░░░░░░] 30%
# class: normal | zero (red) | muted (dim). Updates live via `pactl subscribe`.
# usage: volume.sh [cells]   (20 on desktop, 10 on the laptop bar)

CELLS=${1:-20}
DIM="#1f8f0b"; last=""
cells() { local s="" k; for ((k = 0; k < $2; k++)); do s+=$1; done; printf '%s' "$s"; }

emit() {
  local raw vol muted=0 n bar cls icon
  raw=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null)     # "Volume: 0.45 [MUTED]"
  vol=$(awk '{printf "%d", $2 * 100 + 0.5}' <<< "$raw")
  [[ $raw == *MUTED* ]] && muted=1
  vol=${vol:-0}

  if (( muted )); then
    cls=muted; icon="󰝟"
    bar="<span foreground='$DIM'>[$(cells ░ "$CELLS")]</span> MUTE"
  elif (( vol == 0 )); then
    cls=zero;  icon="󰖁"
    bar="[$(cells ░ "$CELLS")] 0%"                       # whole module goes red via CSS
  else
    cls=normal; icon="󰕾"
    n=$(( (vol * CELLS + 99) / 100 )); (( n > CELLS )) && n=$CELLS
    bar="<span foreground='$DIM'>[</span>$(cells █ "$n")<span foreground='$DIM'>$(cells ░ $((CELLS - n)))]</span> ${vol}%"
  fi

  local out
  out=$(printf '{"text":"%s %s","class":"%s","tooltip":"Volume Control · %s%%\\nscroll adjust · click mute · right-click mixer"}' \
        "$icon" "$bar" "$cls" "$vol")
  [[ $out != "$last" ]] && { echo "$out"; last=$out; }
}

emit
if command -v pactl >/dev/null; then
  pactl subscribe 2>/dev/null | while read -r line; do
    [[ $line == *"sink"* || $line == *"server"* ]] && emit
  done
else
  while sleep 0.5; do emit; done
fi
