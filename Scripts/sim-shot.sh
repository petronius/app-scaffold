#!/bin/bash
# sim-shot.sh <udid> <app-path> <output.png> [launch arguments ...]
#
# Headless screenshot of the app in a state set by DEBUG launch arguments
# (App/Sources/Debug/LaunchOptions.swift). Boots the device without
# Simulator.app, reinstalls the app (uninstall first: `simctl install` over an
# existing bundle can keep serving the old binary), launches it, waits for it
# to settle and captures the screen.
#
#   Scripts/sim-shot.sh $UDID $APP /tmp/items.png -DebugFixture 1 -DebugTab items
#
# The caller creates and later deletes its own device (CLAUDE.md,
# "Verification is headless, always"). For the watch app, set
# SIM_SHOT_BUNDLE=com.example.scaffold.watchkitapp and pass the watch app's
# path and a watch device. SIM_SHOT_APPEARANCE=dark captures dark mode.
set -euo pipefail

UDID="$1"; APP="$2"; OUT="$3"; shift 3
BUNDLE="${SIM_SHOT_BUNDLE:-com.example.scaffold}"
SETTLE="${SIM_SHOT_SETTLE:-4}"

xcrun simctl bootstatus "$UDID" -b >/dev/null 2>&1 || xcrun simctl boot "$UDID"
xcrun simctl bootstatus "$UDID" -b >/dev/null
xcrun simctl ui "$UDID" appearance "${SIM_SHOT_APPEARANCE:-light}" >/dev/null 2>&1 || true
# A fixed status bar, so screenshots differ only by the app.
xcrun simctl status_bar "$UDID" override --time 9:41 --batteryState charged --batteryLevel 100 \
    --cellularBars 4 --wifiBars 3 >/dev/null 2>&1 || true
xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1 || true
xcrun simctl uninstall "$UDID" "$BUNDLE" >/dev/null 2>&1 || true
xcrun simctl install "$UDID" "$APP"
xcrun simctl launch "$UDID" "$BUNDLE" "$@" >/dev/null
sleep "$SETTLE"
xcrun simctl io "$UDID" screenshot "$OUT" >/dev/null 2>&1
echo "$OUT"
