#!/usr/bin/env bash
# ☢ Battery meter for Waybar (laptop):  󰁹 [████████░░] 82%
# class: charging (pulsing green) | full | ok | warm (≤25%, amber) | hot (≤10%, flashing red)
# usage: battery.sh [cells]

DIM="#1f8f0b"
CELLS=${1:-10}
cells() { local s="" k; for ((k = 0; k < $2; k++)); do s+=$1; done; printf '%s' "$s"; }

bat=${REACTOR_BAT:-$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -n1)}
if [[ -z $bat ]]; then
  echo '{"text":"󰂑 AC","class":"full","tooltip":"no battery found"}'; exit 0
fi

pct=$(cat "$bat/capacity" 2>/dev/null || echo 0)
status=$(cat "$bat/status" 2>/dev/null || echo Unknown)

# watts + time left (energy_* in µWh, or charge_* in µAh × voltage)
watts="" eta=""
if [[ -r $bat/power_now ]]; then
  p=$(cat "$bat/power_now"); e_now=$(cat "$bat/energy_now" 2>/dev/null); e_full=$(cat "$bat/energy_full" 2>/dev/null)
else
  v=$(cat "$bat/voltage_now" 2>/dev/null || echo 0)
  p=$(( $(cat "$bat/current_now" 2>/dev/null || echo 0) * v / 1000000 ))
  e_now=$(( $(cat "$bat/charge_now" 2>/dev/null || echo 0) * v / 1000000 ))
  e_full=$(( $(cat "$bat/charge_full" 2>/dev/null || echo 0) * v / 1000000 ))
fi
if [[ -n $p ]] && (( p > 0 )); then
  watts=$(awk -v p="$p" 'BEGIN{printf "%.1f W", p/1e6}')
  if [[ $status == Discharging && -n $e_now ]]; then mins=$(( e_now * 60 / p ))
  elif [[ $status == Charging && -n $e_full && -n $e_now ]]; then mins=$(( (e_full - e_now) * 60 / p ))
  fi
  [[ -n ${mins:-} ]] && eta=$(printf '%dh %02dm' $((mins / 60)) $((mins % 60)))
fi

n=$(( (pct * CELLS + 99) / 100 )); (( n > CELLS )) && n=$CELLS
if   [[ $status == Charging ]];          then cls=charging; icon="󰂄"
elif [[ $status == Full ]] || { (( pct >= 98 )) && [[ $status != Discharging ]]; }; then cls=full; icon="󰁹"
elif (( pct <= 10 )); then cls=hot;  icon="󰂃"
elif (( pct <= 25 )); then cls=warm; icon="󰁻"
else cls=ok; icon="󰁹"; (( pct < 80 )) && icon="󰂀"; (( pct < 55 )) && icon="󰁾"
fi

tip="Battery · $pct% · $status"
[[ -n $watts ]] && tip+="\\n$watts"
[[ -n $eta && $status == Discharging ]] && tip+=" · $eta left"
[[ -n $eta && $status == Charging ]] && tip+=" · full in $eta"

printf '{"text":"%s <span foreground=\\"%s\\">[</span>%s<span foreground=\\"%s\\">%s]</span> %s%%","class":"%s","tooltip":"%s"}\n' \
  "$icon" "$DIM" "$(cells █ "$n")" "$DIM" "$(cells ░ $((CELLS - n)))" "$pct" "$cls" "$tip"
