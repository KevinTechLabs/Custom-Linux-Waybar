#!/usr/bin/env bash
# ☢ Live full-screen reactor monitor (opens when you click the center module). q to quit.

G=$'\e[38;2;57;255;20m'; D=$'\e[38;2;31;143;11m'; A=$'\e[38;2;255;176;0m'
X=$'\e[38;2;255;42;42m'; B=$'\e[1m'; R=$'\e[0m'
printf '\e[?25l\e[?1049h'; trap 'printf "\e[?25h\e[?1049l"' EXIT

pt=0 pi=0 load=0 f=0

gauge() {  # label value(0-100) unit
  local w=30 n=$(( $2 * 30 / 100 )) c=$G
  (( $2 >= 60 )) && c=$A; (( $2 >= 85 )) && c=$X
  printf '  %s%-14s%s ' "$D" "$1" "$c"
  printf '█%.0s' $(seq 1 $n) 2>/dev/null
  printf '%s' "$D"; printf '░%.0s' $(seq 1 $((w - n))) 2>/dev/null
  printf ' %s%3s%s%s\e[K\n' "$c$B" "$2" "$3" "$R"
}

temp() {
  for h in /sys/class/hwmon/hwmon*; do
    case $(cat "$h/name" 2>/dev/null) in k10temp|coretemp|zenpower)
      echo $(( $(cat "$h/temp1_input") / 1000 )); return;; esac
  done; echo 0
}

while true; do
  read -r _ u n s i w q sq st _ < /proc/stat
  t=$((u+n+s+i+w+q+sq+st)) id=$((i+w))
  (( pt )) && (( t > pt )) && load=$(( 100 * ((t-pt) - (id-pi)) / (t-pt) ))
  pt=$t pi=$id

  mem=$(awk '/MemTotal/{t=$2}/MemAvailable/{a=$2}END{printf "%d",(t-a)*100/t}' /proc/meminfo)
  ct=$(temp)
  gt=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -n1)
  gu=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null | head -n1)
  up=$(uptime -p | sed 's/up //')

  status="${G}● NOMINAL"; (( load >= 60 )) && status="${A}▲ ELEVATED"; (( load >= 90 )) && status="${X}⚠ CRITICAL"

  printf '\e[H'
  printf '\n  %s☢  R E A C T O R   M O N I T O R%s            %s\e[K\n' "$G$B" "$R" "$status$R"
  printf '  %s%s\e[K%s\n\n' "$D" "──────────────────────────────────────────────────" "$R"
  gauge "CPU LOAD"  "$load"        "%"
  gauge "CPU TEMP"    "$ct"          "°"
  gauge "GPU TEMP" "${gt:-0}"     "°"
  gauge "GPU LOAD" "${gu:-0}"     "%"
  gauge "RAM"          "$mem"         "%"
  printf '\n  %sUPTIME%s  %s\e[K\n' "$D" "$G" "$up"
  printf '\n  %s[q] exit monitor%s\e[K\n' "$D" "$R"

  f=$((f + 1))
  read -rsn1 -t 0.5 key && [[ $key == q ]] && break
done
