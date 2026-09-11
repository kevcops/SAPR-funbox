#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run this installer with sudo: sudo ./install.sh"
  exit 1
fi

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FUNBOX_USER="funbox"
FUNBOX_HOME="/home/${FUNBOX_USER}"
MEDIA_ROOT="/srv/funbox/karaoke"

echo "==> Updating apt metadata"
apt-get update

echo "==> Installing appliance dependencies"
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  sudo curl ca-certificates git ffmpeg pulseaudio-utils \
  xserver-xorg xinit openbox chromium \
  plymouth plymouth-themes \
  network-manager network-manager-gnome tint2 lxpolkit zenity dbus-x11 rfkill \
  avahi-daemon libnss-mdns \
  unclutter fonts-dejavu-core \
  rsync zip jq

if ! id "${FUNBOX_USER}" >/dev/null 2>&1; then
  echo "==> Creating dedicated appliance user: ${FUNBOX_USER}"
  useradd -m -s /bin/bash "${FUNBOX_USER}"
fi

echo "==> Creating media directories"
# PiKaraoke itself runs as the unprivileged funbox account and writes downloads
# directly below MEDIA_ROOT. Create the root explicitly as funbox-owned; when
# install -d creates missing intermediate directories implicitly they otherwise
# inherit root ownership from this root-run installer.
install -d -m 0755 -o "${FUNBOX_USER}" -g "${FUNBOX_USER}" "${MEDIA_ROOT}"
install -d -m 0755 -o "${FUNBOX_USER}" -g "${FUNBOX_USER}" "${MEDIA_ROOT}/top-karaoke"
install -d -m 0755 -o "${FUNBOX_USER}" -g "${FUNBOX_USER}" "${MEDIA_ROOT}/events/current"
install -d -o "${FUNBOX_USER}" -g "${FUNBOX_USER}" "${FUNBOX_HOME}/.config/openbox"

# Repair ownership on reruns too. This fixes machines installed by older
# versions where /srv/funbox/karaoke was created as root and PiKaraoke could
# browse but failed with EACCES when downloading a song.
chown -R "${FUNBOX_USER}:${FUNBOX_USER}" "${MEDIA_ROOT}"

# install -d can create intermediate parent directories as root. The dedicated
# account must own its entire home before uv/Deno write shell configuration.
chown -R "${FUNBOX_USER}:${FUNBOX_USER}" "${FUNBOX_HOME}"

echo "==> Configuring NetworkManager for renter-facing networking"
# A minimal Debian install may leave the installer-used Wi-Fi connection in
# /etc/network/interfaces. ifupdown then starts its own wpa_supplicant process,
# which races NetworkManager for the same radio. Funbox uses NetworkManager as
# the single owner of Ethernet and Wi-Fi so the graphical setup can scan and
# change networks reliably.
if [[ -f /etc/network/interfaces && ! -f /etc/network/interfaces.funbox-backup ]]; then
  cp -a /etc/network/interfaces /etc/network/interfaces.funbox-backup
fi
cat >/etc/network/interfaces <<'EOF'
# SAPR Funbox: physical networking is managed exclusively by NetworkManager.
auto lo
iface lo inet loopback
EOF

install -d /etc/NetworkManager/conf.d
cat >/etc/NetworkManager/conf.d/10-funbox-managed.conf <<'EOF'
[ifupdown]
managed=true
EOF

# The renter-facing graphical session runs as the locked-down funbox account.
# Permit only NetworkManager operations needed to select/connect Wi-Fi without
# exposing the SAPR administrator password or granting general sudo access.
install -d /etc/polkit-1/rules.d
cat >/etc/polkit-1/rules.d/49-funbox-networkmanager.rules <<EOF
polkit.addRule(function(action, subject) {
    if (subject.user == "${FUNBOX_USER}" &&
        (action.id == "org.freedesktop.NetworkManager.settings.modify.system" ||
         action.id == "org.freedesktop.NetworkManager.settings.modify.own" ||
         action.id == "org.freedesktop.NetworkManager.network-control" ||
         action.id == "org.freedesktop.NetworkManager.enable-disable-wifi")) {
        return polkit.Result.YES;
    }
});
EOF
chmod 0644 /etc/polkit-1/rules.d/49-funbox-networkmanager.rules

echo "==> Configuring customer karaoke address (karaoke.local)"
# Keep the system hostname as "funbox" for administration/Tailscale while
# advertising a stable customer-facing mDNS hostname on the local network.
if [[ -f /etc/avahi/avahi-daemon.conf && ! -f /etc/avahi/avahi-daemon.conf.funbox-backup ]]; then
  cp -a /etc/avahi/avahi-daemon.conf /etc/avahi/avahi-daemon.conf.funbox-backup
fi
sed -i '/^host-name=/d;/^#host-name=/d' /etc/avahi/avahi-daemon.conf
sed -i '/^\[server\]/a host-name=karaoke' /etc/avahi/avahi-daemon.conf
systemctl enable --now avahi-daemon.service
systemctl restart avahi-daemon.service

echo "==> Installing Tailscale for remote support"
# Use Tailscale's official Debian repository rather than the convenience
# installer so factory installs are predictable and repeatable.
. /etc/os-release
TAILSCALE_CODENAME="${VERSION_CODENAME:-trixie}"
install -d -m 0755 /usr/share/keyrings
curl -fsSL "https://pkgs.tailscale.com/stable/debian/${TAILSCALE_CODENAME}.noarmor.gpg" \
  -o /usr/share/keyrings/tailscale-archive-keyring.gpg
curl -fsSL "https://pkgs.tailscale.com/stable/debian/${TAILSCALE_CODENAME}.tailscale-keyring.list" \
  -o /etc/apt/sources.list.d/tailscale.list
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y tailscale
systemctl enable --now tailscaled.service

echo "==> Installing uv for PiKaraoke"
sudo -u "${FUNBOX_USER}" -H bash -lc \
  'if [[ ! -x "$HOME/.local/bin/uv" && ! -x "$HOME/.cargo/bin/uv" ]]; then curl -fsSL https://astral.sh/uv/install.sh | sh; fi'

echo "==> Installing Deno for PiKaraoke/yt-dlp"
sudo -u "${FUNBOX_USER}" -H bash -lc \
  'if [[ ! -x "$HOME/.deno/bin/deno" ]] && ! command -v node >/dev/null 2>&1; then curl -fsSL https://deno.land/install.sh | sh; fi'

echo "==> Installing PiKaraoke as dedicated appliance user"
sudo -u "${FUNBOX_USER}" -H bash -lc \
  'export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$HOME/.deno/bin:$PATH"; if uv tool list 2>/dev/null | grep -q "pikaraoke"; then uv tool upgrade pikaraoke; else uv tool install pikaraoke; fi'

echo "==> Installing appliance scripts"
for f in funbox-status funbox-restart funbox-support funbox-library funbox-event funbox-wifi-setup; do
  install -m 0755 "${REPO_DIR}/scripts/${f}" "/usr/local/bin/${f}"
done

echo "==> Installing PiKaraoke service"
install -m 0644 "${REPO_DIR}/systemd/pikaraoke.service" /etc/systemd/system/pikaraoke.service

echo "==> Installing X kiosk files"
install -m 0644 "${REPO_DIR}/templates/xinitrc" "${FUNBOX_HOME}/.xinitrc"
install -m 0644 "${REPO_DIR}/templates/openbox-autostart" "${FUNBOX_HOME}/.config/openbox/autostart"
chown -R "${FUNBOX_USER}:${FUNBOX_USER}" "${FUNBOX_HOME}/.xinitrc" "${FUNBOX_HOME}/.config"

echo "==> Configuring tty1 autologin for the appliance account"
install -d /etc/systemd/system/getty@tty1.service.d
cat >/etc/systemd/system/getty@tty1.service.d/override.conf <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin ${FUNBOX_USER} --noclear %I \$TERM
Type=idle
EOF

cat >"${FUNBOX_HOME}/.bash_profile" <<'EOF'
if [[ -z "${DISPLAY:-}" ]] && [[ "$(tty)" == "/dev/tty1" ]]; then
  exec startx
fi
EOF
chown "${FUNBOX_USER}:${FUNBOX_USER}" "${FUNBOX_HOME}/.bash_profile"

echo "==> Installing Karaoke Plymouth splash"
install -d /usr/share/plymouth/themes/sa-party-karaoke
install -m 0644 "${REPO_DIR}/assets/splash/karaoke/sa-party-karaoke.plymouth" \
  /usr/share/plymouth/themes/sa-party-karaoke/sa-party-karaoke.plymouth
install -m 0644 "${REPO_DIR}/assets/splash/karaoke/sa-party-karaoke.script" \
  /usr/share/plymouth/themes/sa-party-karaoke/sa-party-karaoke.script
plymouth-set-default-theme -R sa-party-karaoke || true

echo "==> Enabling services"
systemctl daemon-reload
systemctl enable NetworkManager.service
systemctl enable pikaraoke.service
systemctl set-default graphical.target

echo
echo "Install complete."
echo "Permanent songs: ${MEDIA_ROOT}/top-karaoke"
echo "Current event:    ${MEDIA_ROOT}/events/current"
echo "Wi-Fi setup:      opens automatically at startup when offline"
echo "Customer URL:     http://karaoke.local:5555"
echo "Tailscale:        installed and tailscaled enabled"
echo
echo "To enroll this Funbox in your Tailscale network, run:"
echo "  sudo tailscale up --hostname=funbox"
echo
echo "Reboot with: sudo reboot"
