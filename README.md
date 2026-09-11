# SAPR Funbox

A Debian-based appliance image for SA Party Rental.

## v1 goal

Turn a clean Debian install into a dedicated PiKaraoke rental box:

- no full desktop environment
- boot splash branded for SA Party Rental + Karaoke
- PiKaraoke starts automatically
- Chromium opens the local PiKaraoke player fullscreen
- local karaoke storage only
- permanent "Top Karaoke" library + event-specific library
- Tailscale-ready remote support
- clean structure for adding Retro Gaming / EmulationStation later

## Planned modes

- `karaoke` — implemented in v1
- `retro` — reserved for a later release
- `combo` — possible future release

The eventual mode selector can swap services and splash assets without reinstalling Debian.

## Recommended clean Debian install

Install current Debian stable with:

- standard system utilities
- SSH server (recommended)
- **no desktop environment**
- a normal admin user with sudo privileges

Ethernet is easiest for first setup. Wi-Fi works once NetworkManager is configured.

## Install

Clone this repository and run:

```bash
git clone https://github.com/kevcops/SAPR-funbox.git
cd SAPR-funbox
sudo ./install.sh
```

The installer creates a dedicated `funbox` appliance user, installs PiKaraoke using the upstream installation method, installs a minimal X/Chromium kiosk stack, creates the local song library, and enables startup services.

Reboot when it finishes:

```bash
sudo reboot
```

## Local library layout

Runtime media lives outside the Git repository:

```text
/srv/funbox/karaoke/
├── top-karaoke/
└── events/
    └── current/
```

`top-karaoke/` is the permanent house catalog.

`events/current/` is for the current customer's requested songs. Clear or replace that folder between rentals.

The folders under `library/` in this repository are documentation/placeholders only. Song files should **not** be committed to Git.

## Top karaoke catalog

`config/top-karaoke.csv` is a manifest for the house catalog. It intentionally does not contain copyrighted media or hard-coded third-party download URLs.

Use:

```bash
funbox-library status
```

to see the library state.

Use:

```bash
funbox-library import /path/to/authorized/media
```

to copy locally owned/licensed karaoke files into the permanent catalog.

For event songs:

```bash
funbox-event import /path/to/event/media
funbox-event clear
```

PiKaraoke itself supports adding compatible online media through its own interface where you have permission to download/use the source.

## Branding and splash screens

The repo is already split by product:

```text
assets/
├── branding/
│   └── logo.png
└── splash/
    ├── karaoke/
    └── retro/
```

v1 installs the Karaoke Plymouth theme.

Replace `assets/branding/logo.png` and/or the final splash artwork before deploying a branded production unit. The included splash is a safe text-based placeholder so the installer works before final artwork is added.

The Retro directory is intentionally present now so the future Retro package can use its own:

**SA Party Rental + Retro Gaming**

boot experience.

## Useful commands

```bash
funbox-status
funbox-restart
funbox-support
funbox-library status
funbox-event clear
```

## Troubleshooting

Generate a support bundle:

```bash
funbox-support
```

The bundle is written to the current user's home directory and contains service status, journal excerpts, network information, display information and disk usage. It does not copy karaoke media.

## Architecture

```text
Debian
├── Plymouth branded boot splash
├── PiKaraoke service
├── Xorg + Openbox
├── Chromium kiosk
├── local media only
├── Tailscale (optional)
└── future/
    └── Retro / EmulationStation / RetroArch
```

PiKaraoke is kept upstream rather than vendored into this repository so it can be upgraded independently.

## Retro roadmap

The `future/retro/` area is reserved for:

- EmulationStation
- RetroArch
- selected emulator cores / standalone emulators
- controller mappings
- 5–20 curated titles per console
- `rental-mode karaoke|retro`
- Retro-specific splash
- optional `combo` selector

Do not install Batocera itself into this Debian image. We can use Batocera as a configuration/reference source when the Retro mode is implemented.
