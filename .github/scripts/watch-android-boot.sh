#!/usr/bin/env bash
# Runs before emulator launch, so a boot timeout still leaves useful diagnostics.
# The workflow bounds this process with timeout; never dump app/environment data.
set -uo pipefail
adb start-server
while true; do
  date -u
  adb devices -l
  if [[ "$(timeout 10s adb -s emulator-5554 get-state 2>/dev/null)" == "device" ]]; then
    # Start once ADB comes online, even if Android has not finished booting.
    adb -s emulator-5554 logcat -v threadtime > artifacts/android-logcat.txt 2>&1 &
    logcat_pid=$!
    trap 'kill "$logcat_pid" 2>/dev/null || true' EXIT
    while true; do
      date -u
      timeout 10s adb -s emulator-5554 shell getprop sys.boot_completed || true
      sleep 10
    done
  fi
  sleep 5
done
