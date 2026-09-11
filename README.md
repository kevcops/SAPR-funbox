# SAPR Funbox

A Debian-based appliance image for SA Party Rental.

## v1 goal

Turn a clean Debian install into a dedicated PiKaraoke rental box:

- no full desktop environment
- SAPR-branded boot and karaoke idle screens
- PiKaraoke starts automatically
- Chromium opens the local PiKaraoke player fullscreen
- local karaoke storage only
- permanent "Top Karaoke" library + event-specific library
- PipeWire/WirePlumber audio with HDMI, analog/PA, and Bluetooth output selection
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

The installer creates a dedicated `funbox` appliance user, installs PiKaraoke, applies the SAPR Funbox branding layer, installs a minimal X/Chromium kiosk stack, configures PipeWire/WirePlumber audio, creates the local song library, and enables startup services.

Reboot when it finishes:

```bash
sudo reboot
```

## Branding

The approved v1 visual system is:

- Plum `#7D6A89` — primary UI / TV idle background
- Coral `#F38C88` — primary actions and highlights
- Aqua `#A6E1E3` — secondary/selected states
- Cream `#EFE5CF` — light surfaces and backgrounds
- Manrope — phone/controller and system UI
- Fredoka — the display word **KARAOKE** only

The canonical SA Party Rental logo is `assets/branding/sa-party-logo.svg`. Do not redraw, typeset, or reconstruct the individual logo letters. The installer renders that exact SVG to PNG for PiKaraoke and Plymouth.

PiKaraoke remains an upstream uv package. `scripts/funbox-branding-install` reapplies the small SAPR theme/template overlay after every PiKaraoke install or upgrade, so we do not maintain a full fork just for branding.

The branded experience is intended to expose SAPR Funbox rather than Debian/PiKaraoke during normal operation:

```text
Power on
  -> plum SAPR Funbox boot splash
  -> Wi-Fi chooser only when needed
  -> SAPR Karaoke idle/player screen
  -> song playback
```

## Audio

Funbox uses PipeWire and WirePlumber for the appliance user's audio session. ALSA remains the hardware layer underneath it.

At kiosk startup Funbox clears lingering ALSA hardware mute state, prefers an available HDMI/TV output, falls back to analog/headphone when HDMI is unavailable, and sets a known startup volume.

Use the audio helper from the administrator account:

```bash
sudo funbox-audio status
sudo funbox-audio auto
sudo funbox-audio hdmi
sudo funbox-audio analog
sudo funbox-audio bluetooth
```

`auto` prefers HDMI when a usable HDMI sink exists, otherwise it selects analog. Use `analog` when the headphone jack is feeding a PA/mixer even if an HDMI display is connected. `bluetooth` selects the first connected Bluetooth audio sink.

Bluetooth support uses BlueZ + PipeWire/WirePlumber. To pair or connect a speaker from the Funbox graphical session, run:

```bash
funbox-bluetooth-setup
```

Once the speaker is connected and appears as a PipeWire sink, select it with `sudo funbox-audio bluetooth`. A branded web audio selector is planned on top of this backend.

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
sudo funbox-audio bluetooth
funbox-bluetooth-setup
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
├── Plymouth SAPR boot splash
├── PiKaraoke engine + SAPR branding overlay
├── Xorg + Openbox
├── Chromium kiosk
├── PipeWire + WirePlumber
│   ├── HDMI / TV output
│   ├── Analog / headphone / PA output
│   └── Bluetooth speaker output
├── BlueZ / Blueman pairing
├── local media only
├── Tailscale (optional)
└── future/
    └── Retro / EmulationStation / RetroArch
```

PiKaraoke is kept upstream rather than vendored into this repository so it can be upgraded independently. The installer reapplies SAPR's narrow presentation-layer modifications after upgrades.

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
