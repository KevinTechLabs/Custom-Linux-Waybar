#!/usr/bin/env bash
# ☢ Tailscale VPN module for Waybar — "[ 󰌾 ] VPN" / "[ 󰌾 ] California" style.
#   tailscale.sh          -> JSON status (class: on | off | missing)
#   tailscale.sh toggle   -> connect / disconnect, then refresh the bar
# Shows "VPN" normally, or the state / country when routed through an exit node. Toggling without sudo needs a one-time:
#   sudo tailscale set --operator=$USER

LOCK="󰌾"; UNLOCK="󰌿"; DIM="#1f8f0b"; RED="#ff2a2a"

if [[ $1 == toggle ]]; then
  if tailscale status --json 2>/dev/null | grep -q '"BackendState": *"Running"'; then
    tailscale down
  else
    tailscale up
  fi
  pkill -RTMIN+9 waybar
  exit 0
fi

br() {  # icon icon-color label
  printf "<span foreground='%s'>[</span> <span foreground='%s'>%s</span> <span foreground='%s'>]</span> %s" \
    "$DIM" "$2" "$1" "$DIM" "$3"
}

if ! command -v tailscale >/dev/null; then
  printf '{"text":"%s","class":"missing","tooltip":"Tailscale is not installed"}\n' "$(br "$UNLOCK" "$DIM" N/A)"
  exit 0
fi

# state|ip|peers-online|exit-node-name|exit-node-place   (python, no jq needed)
# The place comes from a geo lookup of your public IP while routed through the
# exit node: the STATE for US exits, the COUNTRY everywhere else. It's cached
# per exit node for 10 minutes, so the bar isn't calling out every 5 seconds.
IFS='|' read -r state ip peers exname place < <(tailscale status --json 2>/dev/null | python3 -c '
import json, os, sys, time, urllib.request
try: d = json.load(sys.stdin)
except Exception: print("Stopped||||"); sys.exit()
peers = d.get("Peer") or {}
online = sum(1 for p in peers.values() if p.get("Online"))
ex, place = "", ""
for p in peers.values():
    if p.get("ExitNode"):
        ex = p.get("HostName") or "exit node"
        loc = p.get("Location") or {}
        cache = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "reactor-vpn-geo.json")
        try: c = json.load(open(cache))
        except Exception: c = {}
        if c.get("node") == ex and time.time() - c.get("t", 0) < 600:
            place = c.get("place", "")
        else:
            try:
                g = json.load(urllib.request.urlopen(
                    "http://ip-api.com/json/?fields=status,country,countryCode,regionName", timeout=3))
                if g.get("status") == "success":
                    place = g.get("regionName") if g.get("countryCode") == "US" else g.get("country")
            except Exception: pass
            if not place:   # offline lookup failed: use what Tailscale knows
                place = loc.get("Country") or ""
            json.dump({"node": ex, "place": place, "t": time.time()}, open(cache, "w"))
ips = (d.get("Self") or {}).get("TailscaleIPs") or [""]
print("|".join([d.get("BackendState", ""), ips[0], str(online), ex, place or ""]))
')

if [[ $state == Running ]]; then
  if [[ -n $exname ]]; then
    label=${place:-$exname}
    via="via exit node $exname${place:+ ($place)}"
  else
    label=VPN
    via="direct (no exit node)"
  fi
  printf '{"text":"%s","class":"on","tooltip":"VPN Status / Toggle\\nconnected · %s\\n%s\\n%s devices online"}\n' \
    "$(br "$LOCK" "#39ff14" "$label")" "$via" "$ip" "$peers"
else
  printf '{"text":"%s","class":"off","tooltip":"VPN Status / Toggle\\ndisconnected"}\n' \
    "$(br "$UNLOCK" "$RED" OFF)"
fi
