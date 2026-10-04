#!/usr/bin/env bash
# ☢ Set a power profile from the sidebar and refresh the bar badge.
command -v powerprofilesctl >/dev/null || exit 0
powerprofilesctl set "$1" && pkill -RTMIN+10 waybar
