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
- PipeWire/WirePlumber audio with HDMI and analog/PA output selection
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

The installer creates a dedicated `funbox` appliance user, installs PiKaraoke, installs a minimal X/Chromium kiosk stack, configures PipeWire/WirePlumber audio, creates the local song library, and enables startup services.

Reboot when it finishes:

```bash
sudo reboot
```

## Audio

Funbox uses PipeWire and WirePlumber for the appliance user's audio session. ALSA remains the hardware layer underneath it.

At kiosk startup Funbox:

1. clears lingering ALSA hardware mute state without assuming a fixed sound-card number;
2. prefers an available HDMI/TV output;
3. falls back to the analog/headphone output when HDMI audio is unavailable; and
4. sets the selected PipeWire sink to a known startup volume.

Use the audio helper from the administrator account:

```bash
sudo funbox-audio status
sudo funbox-audio auto
sudo funbox-audio hdmi
sudo funbox-audio analog
```

`auto` prefers HDMI when a usable HDMI sink exists, otherwise it selects analog. Use `analog` when the headphone jack is feeding a PA/mixer even if an HDMI display is also connected. Use `hdmi` when sound should travel to the TV/receiver over HDMI.

The helper operates on the dedicated `funbox` user's PipeWire session, so it can change the live Chromium/PiKaraoke output even when invoked remotely over SSH as the administrator. Existing audio streams are moved to the newly selected sink.

The default startup volume is 80%. It can be overridden for a manual invocation by setting `FUNBOX_AUDIO_VOLUME`, for example:

```bash
sudo FUNBOX_AUDIO_VOLUME=0.65 funbox-audio analog
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
sudo funbox-audio status
sudo funbox-audio auto
sudo funbox-audio hdmi
sudo funbox-audio analog
```

## Troubleshooting

Generate a support bundle:

```bash
funbox-support
```

The bundle is written to the current user's home directory and contains service status, journal excerpts, network information, disk usage, ALSA device information, audio-process state and the kiosk audio-startup log when available. It does not copy karaoke media.

For live PipeWire details, use:

```bash
sudo funbox-audio status
```

## Architecture

```text
Debian
├── Plymouth branded boot splash
├── PiKaraoke service
├── Xorg + Openbox
├── Chromium kiosk
├── PipeWire + WirePlumber
│   ├── HDMI / TV output
│   └── Analog / headphone / PA output
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
