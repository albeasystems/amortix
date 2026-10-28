#!/bin/sh
# Re-takes every simulator capture in every app language (needs a booted iPhone 17 Pro Max simulator).
# Usage: sh marketing/capture.sh [es,en,...]
cd "$(dirname "$0")/.."
OUT="$PWD/marketing/source"
UDID=$(xcrun simctl list devices booted | grep -oE '[0-9A-F-]{36}' | head -1)
if [ -z "$UDID" ]; then UDID=$(xcrun simctl list devices available | grep "iPhone 17 Pro Max" | grep -oE '[0-9A-F-]{36}' | head -1); xcrun simctl boot "$UDID"; sleep 8; fi
xcrun simctl status_bar "$UDID" override --time 9:41 --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3
export TEST_RUNNER_MARKETING_OUT="$OUT"
[ -n "$1" ] && export TEST_RUNNER_MARKETING_LANGS="$1"
xcodebuild test -workspace amortix.xcworkspace -scheme amortix \
  -destination "id=$UDID" -only-testing:amortixUITests/MarketingCaptures -derivedDataPath /tmp/amortix-dd 2>&1 | tail -25
