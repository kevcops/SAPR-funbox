#!/usr/bin/env bash
# SAPR Funbox HDMI field diagnostics. Debian/Xorg/Openbox.
set -u
export LC_ALL=C
say(){ printf '\n=== %s ===\n' "$*"; }
run(){ "$@" 2>&1 || true; }
say "SAPR Funbox HDMI diagnostics $(date -Is)"
echo "User: $(id -un)  Host: $(hostname)"
say "Kernel and boot flags"
run uname -a
run cat /proc/cmdline
say "Graphics hardware and drivers"
if command -v lspci >/dev/null; then run lspci -nnk; else echo "lspci unavailable"; fi
say "DRM connector states"
found=0
for p in /sys/class/drm/card*-*/status; do
  [ -f "$p" ] || continue
  found=1
  printf '%s: %s\n' "${p%/status}" "$(cat "$p")"
  modes="${p%/status}/modes"
  [ ! -r "$modes" ] || head -n 12 "$modes"
done
[ "$found" -eq 1 ] || echo "No DRM connector state files found"
say "Sessions"
run loginctl list-sessions --no-legend
run pgrep -a -f 'Xorg|Xwayland|openbox|chromium|pikaraoke'
say "Display environment"
echo "DISPLAY=${DISPLAY:-unset}; XDG_SESSION_TYPE=${XDG_SESSION_TYPE:-unset}"
if command -v xrandr >/dev/null; then
  run xrandr --query
  if [ -r /home/funbox/.Xauthority ]; then
    echo "Checking kiosk display :0 as funbox"
    run sudo -u funbox env DISPLAY=:0 XAUTHORITY=/home/funbox/.Xauthority xrandr --query
  fi
else echo "xrandr unavailable"; fi
say "Kiosk service status"
run systemctl --no-pager --plain --type=service --state=running
say "Recent display errors"
run journalctl -b --no-pager -n 80 -p warning
say "Diagnosis hints"
echo "DRM HDMI disconnected: verify TV input, cable, adapter, port, and power-cycle TV."
echo "DRM HDMI connected but blank after boot: inspect Xorg/xrandr and kiosk session."
echo "nomodeset in boot flags: may disable graphics modesetting."
echo "If BIOS is also invisible, suspect cable/TV/port before Linux."
echo
echo "Optional emergency 1080p fix (changes only active X display; not persistent)."
read -r -p "Attempt 1920x1080 at 60 Hz on a detected connected HDMI output? [y/N] " answer
case "$answer" in y|Y|yes|YES) ;; *) echo "No changes made."; exit 0;; esac
command -v xrandr >/dev/null || { echo "xrandr not installed"; exit 1; }
XR=(xrandr)
if [ -r /home/funbox/.Xauthority ] && command -v sudo >/dev/null; then
  XR=(sudo -u funbox env DISPLAY=:0 XAUTHORITY=/home/funbox/.Xauthority xrandr)
fi
outputs="$("${XR[@]}" --query 2>/dev/null || true)"
target="$(printf '%s\n' "$outputs" | awk '/^HDMI[^ ]* connected/ {print $1; exit}')"
if [ -z "$target" ]; then echo "No connected HDMI output in X session. No changes made."; exit 1; fi
if ! printf '%s\n' "$outputs" | awk -v t="$target" '$1==t {inout=1;next} /^[^ ]/ {inout=0} inout && $1=="1920x1080" {found=1} END {exit !found}'; then
  echo "1920x1080 not advertised by $target. No changes made."; exit 1
fi
echo "Applying 1920x1080 on $target (automatic refresh rate selection)."
"${XR[@]}" --output "$target" --mode 1920x1080 --auto
