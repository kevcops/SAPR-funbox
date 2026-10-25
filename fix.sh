#!/usr/bin/env bash
# SAPR Funbox field diagnostics: read-only, no restart, no changes.
set +e
export LC_ALL=C
OUT="$HOME/funbox-hdmi-report.txt"
{
echo "SAPR Funbox HDMI report $(date -Is)"
echo "Host: $(hostname) User: $(id -un)"
section(){ printf '\n===== %s =====\n' "$1"; }
section "Boot and graphics"
uname -a
cat /proc/cmdline
lspci -nnk 2>&1 | grep -A 5 -Ei 'VGA|Display|3D'
section "Kernel DRM connectors, status and modes"
for p in /sys/class/drm/card*-*/status; do
  [ -f "$p" ] || continue
  echo "$p: $(cat "$p")"
  [ -r "${p%/status}/modes" ] && head -15 "${p%/status}/modes"
done
section "Xorg process and sessions"
pgrep -a Xorg
loginctl list-sessions --no-pager
section "Kiosk user Xrandr"
if command -v xrandr >/dev/null; then
  if [ "$(id -un)" = funbox ]; then
    DISPLAY=:0 XAUTHORITY=/home/funbox/.Xauthority xrandr --query 2>&1
  elif command -v sudo >/dev/null; then
    sudo -n -u funbox env DISPLAY=:0 XAUTHORITY=/home/funbox/.Xauthority xrandr --query 2>&1
  else
    echo "sudo not available"
  fi
else
  echo "xrandr not installed"
fi
section "Xorg log excerpts"
for f in /home/funbox/.local/share/xorg/Xorg.0.log /home/funbox/.local/share/xorg/Xorg.0.log.old /var/log/Xorg.0.log; do
  if [ -r "$f" ]; then
    echo "--- $f ---"
    grep -Ei 'HDMI|amdgpu|EDID|\(EE\)|failed|modesetting|connected|disconnected' "$f" | tail -90
  fi
done
section "Xorg config files"
for f in /etc/X11/xorg.conf /etc/X11/xorg.conf.d/*.conf /usr/share/X11/xorg.conf.d/*.conf; do
  [ -f "$f" ] || continue
  echo "--- $f ---"
  grep -Ei 'Section|Driver|Device|Monitor|Output|Option|BusID' "$f" | head -35
done
section "Relevant services"
systemctl list-units --all --no-pager --plain 2>&1 | grep -Ei 'funbox|pikaraoke|display|kiosk|lightdm|gdm' || true
section "Graphics-related kernel messages (permissions may limit results)"
journalctl -k -b --no-pager 2>&1 | grep -Ei 'amdgpu|drm|HDMI|EDID' | tail -65
section "Done"
echo "No display settings or services were changed."
} 2>&1 | tee "$OUT"
echo
echo "Report saved: $OUT"
echo "Photograph the last sections or share the report for diagnosis."
