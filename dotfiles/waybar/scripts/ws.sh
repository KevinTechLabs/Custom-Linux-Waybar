#!/usr/bin/env bash
# ☢ One workspace button for Waybar, driven straight by hyprctl.
# usage: ws.sh <number>
# Prints {"text","class"} where class = active | occupied | empty.
# Updates instantly from Hyprland's event socket (socat), or polls if socat is missing.

N=${1:-1}
last=""

active_id() {
  hyprctl activeworkspace -j 2>/dev/null | tr -d ' \n' | grep -oE '"id":-?[0-9]+' | head -n1 | cut -d: -f2
}
windows_on() {
  hyprctl workspaces -j 2>/dev/null | tr -d ' \n' \
    | grep -oE "\"id\":$N,[^}]*\"windows\":[0-9]+" | grep -oE '"windows":[0-9]+' | cut -d: -f2
}

emit() {
  local cls=empty w
  if [[ $(active_id) == "$N" ]]; then cls=active
  else w=$(windows_on); (( ${w:-0} > 0 )) && cls=occupied; fi
  local out="{\"text\":\"$N\",\"class\":\"$cls\",\"tooltip\":\"Workspace $N\"}"
  [[ $out != "$last" ]] && { echo "$out"; last=$out; }
}

emit
SOCK="${XDG_RUNTIME_DIR}/hypr/${HYPRLAND_INSTANCE_SIGNATURE}/.socket2.sock"
if command -v socat >/dev/null && [[ -S $SOCK ]]; then
  socat -U - "UNIX-CONNECT:$SOCK" | while read -r ev; do
    case $ev in
      workspace*|focusedmon*|openwindow*|closewindow*|movewindow*|createworkspace*|destroyworkspace*) emit ;;
    esac
  done
else
  while sleep 0.3; do emit; done
fi
