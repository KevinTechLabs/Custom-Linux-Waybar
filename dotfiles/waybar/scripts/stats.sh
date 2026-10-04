#!/usr/bin/env bash
# ☢ Instrument-panel modules for Waybar: two readings per module.
# usage: stats.sh cpu | gpu | ram | ssd | ping
#   CPU  load% │ temp      GPU  load% │ temp
#   RAM  used  │ /total    SSD  used% │ temp
#   PING latency │ loss%    (laptop; target = \$REACTOR_PING_HOST or 1.1.1.1)

DIM="#1f8f0b"
state="${XDG_RUNTIME_DIR:-/tmp}/reactor-cpu.stat"

hwtemp() {  # hwmon driver names... -> °C of the first match
  for h in /sys/class/hwmon/hwmon*; do
    local n; n=$(cat "$h/name" 2>/dev/null)
    for want in "$@"; do
      [[ $n == "$want" && -r $h/temp1_input ]] && { echo $(( $(cat "$h/temp1_input") / 1000 )); return; }
    done
  done
}

level() {  # value warm hot -> ok|warm|hot
  (( $1 >= $3 )) && { echo hot; return; }
  (( $1 >= $2 )) && { echo warm; return; }
  echo ok
}

worst() {  # pick the more serious of two levels
  [[ $1 == hot || $2 == hot ]] && { echo hot; return; }
  [[ $1 == warm || $2 == warm ]] && { echo warm; return; }
  echo ok
}

emit() {  # label primary secondary class tooltip
  local lc="$DIM"; [[ $4 == hot ]] && lc="#000000"
  printf '{"text":"<span size=\\"small\\" foreground=\\"%s\\">%s</span>  <b>%s</b> <span foreground=\\"%s\\">│</span> %s","class":"%s","tooltip":"%s"}\n' \
    "$lc" "$1" "$2" "$lc" "$3" "$4" "$5"
}

case ${1:-cpu} in
  cpu)
    read -r _ u n s i w q sq st _ < /proc/stat
    total=$((u+n+s+i+w+q+sq+st)) idle=$((i+w)) load=0
    if [[ -r $state ]]; then
      read -r pt pi < "$state"
      (( total > pt )) && load=$(( 100 * ((total-pt) - (idle-pi)) / (total-pt) ))
    fi
    echo "$total $idle" > "$state"
    t=$(hwtemp k10temp zenpower coretemp); t=${t:-0}
    cls=$(worst "$(level "$t" 75 88)" "$(level "$load" 85 97)")
    emit "CPU" "${load}%" "${t}°C" "$cls" "CPU load: ${load}%\nCPU temp: ${t}°C"
    ;;

  gpu)
    IFS=', ' read -r load t < <(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu \
      --format=csv,noheader,nounits 2>/dev/null | head -n1)
    if [[ -z $t ]]; then
      t=$(hwtemp amdgpu)
      load=$(cat /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null | head -n1)
    fi
    load=${load:-0} t=${t:-0}
    cls=$(level "$t" 70 83)
    emit "GPU" "${load}%" "${t}°C" "$cls" "GPU load: ${load}%\nGPU temp: ${t}°C"
    ;;

  ram)
    read -r pct used total < <(awk '/MemTotal/{t=$2}/MemAvailable/{a=$2}
      END{printf "%d %.1f %.0f", (t-a)*100/t, (t-a)/1048576, t/1048576}' /proc/meminfo)
    cls=$(level "$pct" 75 90)
    emit "RAM" "${used}G" "/${total}G" "$cls" "RAM: ${used} / ${total} GiB (${pct}%)"
    ;;

  ssd)
    read -r pct used size < <(df -h --output=pcent,used,size / | tail -n1 | tr -d '%')
    t=$(hwtemp nvme); t=${t:-0}
    cls=$(worst "$(level "$pct" 80 92)" "$(level "$t" 60 70)")
    emit "SSD" "${pct}%" "${t}°C" "$cls" "Disk /: ${used} / ${size} used (${pct}%)\nSSD temp: ${t}°C"
    ;;

  ping)
    host=${REACTOR_PING_HOST:-1.1.1.1}
    out=$(LC_ALL=C ping -n -q -c 3 -i 0.2 -W 1 "$host" 2>/dev/null)
    loss=$(grep -oE '[0-9.]+% packet loss' <<< "$out" | cut -d% -f1); loss=${loss%.*}; loss=${loss:-100}
    avg=$(awk -F/ '/^rtt|^round-trip/{printf "%d", $5 + 0.5}' <<< "$out")
    if [[ -z $avg ]] || (( loss >= 100 )); then
      emit "PING" "--" "OFFLINE" "offline" "Ping ${host}: no reply\nNo connection (or ICMP blocked)"
    else
      lcls=ok; (( loss > 0 )) && lcls=warm; (( loss >= 50 )) && lcls=hot
      cls=$(worst "$(level "$avg" 80 200)" "$lcls")
      emit "PING" "${avg}ms" "${loss}%" "$cls" "Ping ${host}: ${avg} ms average\nPacket loss: ${loss}%\nClick for a live ping"
    fi
    ;;
esac
