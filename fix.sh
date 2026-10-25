#!/usr/bin/env bash
# SAPR Funbox: read-only diagnostics; optional guarded graphical session restart.
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

echo
echo "=== NO SIGNAL RECOVERY GUIDE ==="
echo "1. Select the exact HDMI input on the TV."
echo "2. Unplug and reconnect both ends of the HDMI cable."
echo "3. Power-cycle only the TV, leaving the laptop running."
echo "4. If available, try another HDMI cable or TV input."
echo
echo "=== FRESH XORG HDMI STATUS ==="
sudo -n -u funbox env DISPLAY=:0 XAUTHORITY=/home/funbox/.Xauthority xrandr --query 2>&1 | grep -E '^(Screen|eDP|HDMI|DP)|open display|Authorization' || true
echo
echo "=== XORG PROCESS AND USER SESSION ==="
pgrep -a Xorg || true
loginctl list-sessions --no-pager || true
echo
echo "=== NEXT STEP ==="
echo "If Xorg still says disconnected, do not force a resolution."
echo "A controlled restart of the graphical session may be needed."
echo "This script deliberately does not restart Xorg or disrupt PiKaraoke."
echo "Send a photo of this screen."

echo
echo
echo "=== STARTUP PATH INVESTIGATION (READ ONLY) ==="
echo "Auto-login getty:"
systemctl cat getty@tty1.service 2>&1 | tail -45
echo "Funbox login startup references:"
for f in /home/funbox/.bash_profile /home/funbox/.profile /home/funbox/.bash_login /home/funbox/.xinitrc /home/funbox/.xsession /home/funbox/.config/openbox/autostart; do
 if [ -f "$f" ]; then
  echo "--- $f ---"
  grep -nEi 'startx|xinit|Xorg|openbox|chrom|funbox|kiosk|exec|tty' "$f" | head -35
 fi
done
echo "Xorg ancestry:"
pid="$(pgrep -u funbox -x Xorg | head -1)"
if [ -n "$pid" ]; then
 ps -o pid,ppid,user,args -p "$pid"
 command -v pstree >/dev/null && pstree -asp "$pid" | head -8
fi
echo "User units and timers:"
sudo -n -u funbox env XDG_RUNTIME_DIR=/run/user/$(id -u funbox) systemctl --user list-units --all --no-pager 2>&1 | grep -Ei 'xorg|display|kiosk|funbox|graphical|startx' | head -25
echo
echo "No restart attempted. Send a photo of this startup section."

echo
echo "=== EXACT XORG LAUNCH CHAIN ==="
pid="$(pgrep -u funbox -x Xorg | head -1)"
if [ -z "$pid" ]; then
 echo "No funbox Xorg process found."
else
 while [ -n "$pid" ] && [ "$pid" -gt 1 ]; do
  ps -p "$pid" -o pid=,ppid=,user=,args= -ww
  parent="$(ps -p "$pid" -o ppid= | tr -d ' ')"
  [ -z "$parent" ] && break
  [ "$parent" = "$pid" ] && break
  pid="$parent"
 done
fi
echo "=== TTY1 LOGIN DETAILS ==="
loginctl show-session 1 -p Name -p Service -p Type -p TTY -p Leader -p State 2>&1
echo "=== USER LOGIN SCRIPT INVENTORY ==="
ls -la /home/funbox/.bash_profile /home/funbox/.bashrc /home/funbox/.profile /home/funbox/.xinitrc /home/funbox/.xsession 2>&1
echo "=== STARTUP COMMAND SEARCH ==="
grep -RInE 'startx|xinit|Xorg|openbox-session' /home/funbox/.config /home/funbox/.bashrc /home/funbox/.profile /etc/profile.d /etc/systemd/system 2>/dev/null | head -35
echo "No changes made. Send a photo of EXACT XORG LAUNCH CHAIN."
