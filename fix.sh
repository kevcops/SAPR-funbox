#!/usr/bin/env bash
# Quick event-side entry point for HDMI diagnostics.
set -e
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "$HERE/scripts/troubleshoot-hdmi.sh"
