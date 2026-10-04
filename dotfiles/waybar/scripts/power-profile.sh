#!/usr/bin/env bash
# ☢ Reactor power profile for Waybar's center badge.
#   power-profile.sh         -> JSON status
#   power-profile.sh cycle   -> power-saver → balanced → performance → power-saver
# Uses powerprofilesctl (power-profiles-daemon or tuned-ppd).
#
#   power-saver  ->  ☢ REACTOR IDLE       (dim)
#   balanced     ->  ☢ REACTOR ONLINE     (green)
#   performance  ->  ☢ REACTOR OVERDRIVE  (amber, faster pulse)

if ! command -v powerprofilesctl >/dev/null; then
  [[ $1 == cycle ]] && exit 0
  echo '{"text":"<span size=\"x-large\">☢</span>  REACTOR ONLINE","class":"balanced","tooltip":"Power profiles unavailable\nInstall power-profiles-daemon"}'
  exit 0
fi

cur=$(powerprofilesctl get 2>/dev/null)

if [[ $1 == cycle ]]; then
  avail=$(powerprofilesctl list 2>/dev/null)
  case $cur in
    power-saver) next=balanced ;;
    balanced)    next=performance ;;
    *)           next=power-saver ;;
  esac
  # skip performance if this machine doesn't offer it
  [[ $next == performance && $avail != *performance* ]] && next=power-saver
  powerprofilesctl set "$next"
  pkill -RTMIN+10 waybar
  exit 0
fi

case $cur in
  power-saver) label="REACTOR IDLE";      cls=power-saver ;;
  performance) label="REACTOR OVERDRIVE"; cls=performance ;;
  *)           label="REACTOR ONLINE";    cls=balanced ;;
esac

printf '{"text":"<span size=\\"x-large\\">☢</span>  %s","class":"%s","tooltip":"Power profile: %s\\nclick to cycle · right-click for monitor"}\n' \
  "$label" "$cls" "${cur:-unknown}"
