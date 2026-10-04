#!/usr/bin/env bash
# ☢ REACTOR CORE — dashboard-card greeting for new terminals.
# Four cards (CPU / GPU / RAM / DISK) with big readouts and filling bars.
# In kitty: real trefoil image + double-size numbers. Elsewhere: plain text.
# 4 cards across on wide windows, 2×2 on narrower ones. Any key skips animation.
# usage: reactor-gauges.sh [fish-version]

G=$'\e[38;2;57;255;20m'; D=$'\e[38;2;31;143;11m'; A=$'\e[38;2;255;176;0m'
X=$'\e[38;2;255;42;42m'; W=$'\e[38;2;216;255;208m'; K=$'\e[38;2;15;61;8m'
B=$'\e[1m'; R=$'\e[0m'
INV=$'\e[48;2;57;255;20m\e[38;2;0;0;0m\e[1m'
printf '\e[?25l'; trap 'printf "\e[?25h\e[0m"' EXIT

skip=0
nap()  { (( skip )) && return; read -rsn1 -t "$1" && skip=1; }
pad()  { local s=$1; while (( ${#s} < $2 )); do s+=" "; done; printf '%s' "${s:0:$2}"; }
lvl()  { (( $1 >= $3 )) && { printf '%s' "$X"; return; }; (( $1 >= $2 )) && { printf '%s' "$A"; return; }; printf '%s' "$G"; }
rep()  { local s="" k; for ((k = 0; k < $2; k++)); do s+=$1; done; printf '%s' "$s"; }

KITTY=0; [[ -n $KITTY_WINDOW_ID || $TERM == xterm-kitty ]] && KITTY=1

# ---------- readings ----------
read -r _ u n s i w q sq st _ < /proc/stat; t1=$((u+n+s+i+w+q+sq+st)); i1=$((i+w))
sleep 0.15
read -r _ u n s i w q sq st _ < /proc/stat; t2=$((u+n+s+i+w+q+sq+st)); i2=$((i+w))
cload=$(( t2 > t1 ? 100 * ((t2-t1) - (i2-i1)) / (t2-t1) : 0 ))

hw() { for h in /sys/class/hwmon/hwmon*; do for want in "$@"; do
  [[ $(cat "$h/name" 2>/dev/null) == "$want" ]] && { echo $(( $(cat "$h/temp1_input") / 1000 )); return; }
done; done; }
ctemp=$(hw k10temp zenpower coretemp); ctemp=${ctemp:-0}
cpu=$(awk -F: '/model name/{print $2; exit}' /proc/cpuinfo | sed -E 's/^ +//; s/(AMD |Intel\(R\) |Core\(TM\) |[0-9]+-Core Processor|Processor| CPU @.*)//g; s/ +$//')
cpu=${cpu#Ryzen [0-9] }   # "Ryzen 7 9800X3D" -> "9800X3D"

IFS=', ' read -r gload gtemp < <(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -n1)
gpu=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -n1 | sed 's/NVIDIA //; s/GeForce //')
[[ -z $gpu ]] && gpu="GPU" && gtemp=$(hw amdgpu)
gload=${gload:-0} gtemp=${gtemp:-0}

read -r mpct mused mtot < <(awk '/MemTotal/{t=$2}/MemAvailable/{a=$2}
  END{printf "%d %.1f %.1f", (t-a)*100/t, (t-a)/1048576, t/1048576}' /proc/meminfo)
read -r dpct dused dsize < <(df -BG --output=pcent,used,size / | tail -n1 | tr -d '%G')

os=$(. /etc/os-release 2>/dev/null; echo "${NAME:-Linux}")
wm=$(hyprctl version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1); wm=${wm:+Hyprland $wm}
up=$(uptime -p | sed 's/up //; s/ hours\?/h/; s/ minutes\?/m/; s/ days\?/d/; s/,//g; s/ //g')
pkgs=$(pacman -Qq 2>/dev/null | wc -l)
kern=$(uname -r)
shellv=${1:-$(fish --version 2>/dev/null | awk '{print $3}')}

# ---------- card definitions ----------
# title | big value | detail label | detail value | bar % | warn level source | warm | hot
CARDS=(
  "CPU · $cpu|${ctemp}°C|load|${cload}%|$cload|$ctemp|75|88"
  "GPU · $gpu|${gtemp}°C|load|${gload}%|$gload|$gtemp|70|83"
  "RAM|${mused}G|of|${mtot}G|$mpct|$mpct|75|90"
  "DISK|${dused}G|of|${dsize}G|$dpct|$dpct|80|92"
)
CW=26          # card outer width
IW=$((CW - 2)) # inner width
BARW=$((IW - 2))

cols=${COLUMNS:-$(tput cols 2>/dev/null || echo 120)}
PER=4; (( cols < 4 * (CW + 2) + 2 )) && PER=2

# one text row of one card. row: 0 top, 1 big, 2 big-continued, 3 detail, 4 bar, 5 bottom
cell() {  # card-index row frame
  IFS='|' read -r title big dl dv pct src warm hot <<< "${CARDS[$1]}"
  local c; c=$(lvl "$src" "$warm" "$hot")
  local bc=$G; [[ $c != "$G" ]] && bc=$c
  case $2 in
    0) local t=" ${title:0:$((IW - 3))} "; printf '%s┌─%s%s%s%s┐%s' "$bc" "$D" "$t" "$bc" "$(rep ─ $((IW - 1 - ${#t})))" "$R" ;;
    1) if (( KITTY )); then
         printf '%s│ %s%s\e]66;s=2;%s\a%s%s│%s' "$bc" "$c" "$B" "$big" "$(rep ' ' $((IW - 1 - 2 * ${#big})))" "$R$bc" "$R"
       else
         printf '%s│ %s%s%s%s│%s' "$bc" "$c" "$B" "$(pad "$big" $((IW - 1)))" "$R$bc" "$R"
       fi ;;
    2) if (( KITTY )); then printf '%s│ \e[%dC%s│%s' "$bc" $((2 * ${#big})) "$(rep ' ' $((IW - 1 - 2 * ${#big})))" "$R"
       else printf '%s│%s│%s' "$bc" "$(rep ' ' $IW)" "$R"; fi ;;
    3) printf '%s│ %s%s %s%s%s%s│%s' "$bc" "$D" "$dl" "$W" "$(pad "$dv" $((IW - 2 - ${#dl})))" "$R" "$bc" "$R" ;;
    4) local now=$(( pct * $3 / 6 )) n; n=$(( (now * BARW + 50) / 100 )); (( now > 0 && n == 0 )) && n=1
       printf '%s│ %s%s%s%s %s│%s' "$bc" "$c" "$(rep ▰ $n)" "$K" "$(rep ▱ $((BARW - n)))" "$bc" "$R" ;;
    5) printf '%s└%s┘%s' "$bc" "$(rep ─ $IW)" "$R" ;;
  esac
}

draw_cards() {  # frame
  local first row k
  for ((first = 0; first < 4; first += PER)); do
    for ((row = 0; row < 6; row++)); do
      printf '  '
      for ((k = first; k < first + PER; k++)); do cell "$k" "$row" "$1"; printf '  '; done
      printf '\e[K\n'
    done
  done
}

# ---------- header ----------
printf '\n'
IMG="$HOME/.config/reactor/trefoil.png"
if (( KITTY )) && [[ -r $IMG ]]; then
  printf '\n\n\e[2A  '
  data=$(base64 -w 0 "$IMG"); first=1
  while [[ -n $data ]]; do
    chunk=${data:0:4096}; data=${data:4096}; more=$([[ -n $data ]] && echo 1 || echo 0)
    if (( first )); then printf '\e_Gf=100,a=T,r=2,C=1,q=2,m=%s;%s\e\\' "$more" "$chunk"; first=0
    else printf '\e_Gm=%s;%s\e\\' "$more" "$chunk"; fi
  done
  printf '\e[6C'
else
  printf '  %s%s☢%s  ' "$G" "$B" "$R"
fi
printf '%s REACTOR CORE %s  %s%s · up %s%s\n' "$INV" "$R" "$D" "$(whoami)" "$up" "$R"
ind=6; (( KITTY )) && [[ -r $IMG ]] && ind=9
printf '\e[%dC%s%s · %s · %s · %s pkgs · fish %s%s\n\n' "$ind" "$D" "$os" "${wm:-$XDG_CURRENT_DESKTOP}" "$kern" "$pkgs" "$shellv" "$R"

# ---------- cards (animated fill) ----------
rows=$(( 6 * (4 / PER) ))
for f in 0 1 2 3 4 5 6; do
  (( skip )) && f=6
  (( f > 0 )) && printf '\e[%dA' "$rows"
  draw_cards "$f"
  (( f == 6 )) && break
  nap 0.06
done
printf '\n'
