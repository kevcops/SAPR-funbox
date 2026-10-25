#!/usr/bin/env bash
# SAPR Funbox: safe field diagnosis, no service restarts or changes.
set +e
export LC_ALL=C
OUT="$HOME/funbox-hdmi-report.txt"
section(){ printf '\n===== %s =====\n' "$1"; }
{
echo "SAPR HDMI diagnostic: $(date -Is)"
section "Graphics and kernel"
uname -a; cat /proc/cmdline
lspci -nnk 2>&1 | grep -A 5 -Ei 'VGA|Display|3D'
section "Kernel connectors and advertised modes"
for p in /sys/class/drm/card*-*/status; do
 [ -f "$p" ] || continue
 echo "$p: $(cat "$p")"
 [ -r "${p%/status}/modes" ] && head -12 "${p%/status}/modes"
 [ -r "${p%/status}/edid" ] && echo "EDID bytes: $(wc -c < "${p%/status}/edid")"
done
section "Xorg process and sessions"
pgrep -a Xorg; loginctl list-sessions --no-pager
section "Xrandr as funbox"
if command -v xrandr >/dev/null; then
 sudo -n -u funbox env DISPLAY=:0 XAUTHORITY=/home/funbox/.Xauthority xrandr --verbose 2>&1 | head -110
else echo "xrandr missing"; fi
section "Xorg log locations and display errors"
for f in /home/funbox/.local/share/xorg/Xorg.0.log /home/funbox/.local/share/xorg/Xorg.0.log.old /var/log/Xorg.0.log; do
 if [ -f "$f" ]; then
  echo "--- $f ---"
  if [ -r "$f" ]; then
   grep -Ein 'HDMI|EDID|amdgpu|modeset|\(EE\)|failed|disconnect|connect|hotplug|drm' "$f" | tail -110
  else echo "Unreadable as current user"; fi
 fi
done
section "Graphics packages"
dpkg-query -W 'xserver-xorg-video-amdgpu' 'xserver-xorg-core' 'firmware-amd-graphics' 2>&1
section "Xorg device configuration"
for f in /etc/X11/xorg.conf /etc/X11/xorg.conf.d/*.conf /usr/share/X11/xorg.conf.d/*amdgpu*.conf; do
 [ -f "$f" ] || continue
 echo "--- $f ---"; grep -Ein 'Section|Driver|Device|Monitor|Output|Option|BusID' "$f"
done
section "Services and kiosk processes"
systemctl list-units --all --no-pager --plain 2>&1 | grep -Ei 'funbox|pikaraoke|display|kiosk|lightdm|gdm'
pgrep -a -f 'chromium|openbox|startx|pikaraoke' | head -25
section "Kernel display messages"
journalctl -k -b --no-pager 2>&1 | grep -Ei 'amdgpu|drm|HDMI|EDID|hotplug' | tail -85
section "End of report"
echo "Read-only: no changes made."
} > "$OUT" 2>&1
echo
echo "=== SAPR HDMI QUICK SUMMARY ==="
grep -E 'card[0-9]+-HDMI.*status:|HDMI[^ ]* (connected|disconnected)|Kernel driver in use:|EDID bytes:|\(EE\)|failed|Failed|Unreadable|missing|denied' "$OUT" | tail -35
echo
echo "=== XORG DISPLAY ERRORS ==="
sed -n '/===== Xorg log locations/,/===== Graphics packages/p' "$OUT" | tail -50
echo
echo "Full report saved: $OUT"
echo "No settings were changed. Photograph this screen."
