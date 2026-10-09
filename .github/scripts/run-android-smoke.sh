#!/usr/bin/env bash
# The emulator action runs each input line in a separate POSIX shell. Use one
# Bash script so error handling, cleanup and device selection share one process.
set -euo pipefail
mkdir -p artifacts
device="${ANDROID_SERIAL:-emulator-5554}"
capture_device_state() {
  timeout 10s adb -s "$device" shell getprop sys.boot_completed > artifacts/boot-completed.txt 2>&1 || true
  timeout 10s adb -s "$device" shell dumpsys activity activities > artifacts/android-activity.txt 2>&1 || true
  timeout 10s adb -s "$device" exec-out screencap -p > artifacts/android-screen.png 2>/dev/null || true
}
trap capture_device_state EXIT
adb -s "$device" shell input keyevent 82
adb -s "$device" install -r CardTradingPOC/android/app/build/outputs/apk/release/app-release.apk
maestro --device "$device" test --format JUNIT --output artifacts/navigation.xml --debug-output artifacts/maestro-navigation CardTradingPOC/.maestro/smoke.yml
maestro --device "$device" test --env TEST_EMAIL="$TEST_EMAIL" --env TEST_PASSWORD="$TEST_PASSWORD" --format JUNIT --output artifacts/sign-in.xml --debug-output artifacts/maestro-sign-in CardTradingPOC/.maestro/signed-in.yml
