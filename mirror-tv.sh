#!/usr/bin/env bash
# Mirror the running Funbox Xorg desktop to a connected HDMI screen.
set -euo pipefail
if [[ ${EUID} -eq 0 ]]; then echo "Run as sapr, not root (sudo will be requested)."; exit 1; fi
sudo -v
pid="$(pgrep -u funbox -x Xorg | head -n 1 || true)"
if [[ -z "$pid" ]]; then echo "No running funbox Xorg session. No changes made."; exit 1; fi
args="$(ps -ww -p "$pid" -o args=)"
auth="$(printf '%s\n' "$args" | sed -nE 's/.* -auth ([^ ]+).*/\1/p')"
if [[ -z "$auth" || ! -f "$auth" ]]; then echo "Cannot locate active Xorg authorization file. No changes made."; exit 1; fi
run_xrandr(){ sudo -u funbox env DISPLAY=:0 XAUTHORITY="$auth" xrandr "$@"; }
query="$(run_xrandr --query)" || { echo "Unable to access Xorg display. No changes made."; exit 1; }
printf '%s\n' "$query" | grep -E '^(Screen|eDP|HDMI|DP)' || true
hdmi="$(printf '%s\n' "$query" | awk '$1 ~ /^HDMI/ && $2 == "connected" {print $1; exit}')"
internal="$(printf '%s\n' "$query" | awk '$1 ~ /^eDP/ && $2 == "connected" {print $1; exit}')"
if [[ -z "$hdmi" || -z "$internal" ]]; then echo "HDMI or laptop screen is not connected in Xorg. No changes made."; exit 1; fi
echo "Mirroring $internal to $hdmi..."
run_xrandr --output "$hdmi" --auto --same-as "$internal"
echo "Done. Current outputs:"
run_xrandr --query | grep -E '^(Screen|eDP|HDMI|DP)' || true
