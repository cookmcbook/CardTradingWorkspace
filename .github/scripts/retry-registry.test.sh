#!/usr/bin/env sh
# Offline regression checks: fake commands and fake sleep, no Docker/network.
set -eu
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$script_dir/retry-registry.sh"
REGISTRY_LOG_DIR=$(mktemp -d)
sleep() { waits="$waits $1"; }
fake_command() {
  calls=$((calls + 1))
  case "$scenario" in
    recovery)
      if [ "$calls" -eq 1 ]; then
        echo 'failed to resolve source metadata: registry-1.docker.io/v2/library/node/manifests/24-alpine: 429 Too Many Requests'
        return 7
      fi ;;
    persistent)
      echo 'Error response from daemon: toomanyrequests: You have reached your pull rate limit'
      return 8 ;;
    compilation)
      echo 'load metadata for docker.io/library/node:24-alpine DONE'
      echo 'npm ERR! 429 Too Many Requests from registry.npmjs.org'
      return 9 ;;
    missing)
      echo 'failed to resolve source metadata: registry-1.docker.io: manifest unknown'
      return 10 ;;
  esac
  return 0
}
for scenario in recovery persistent compilation missing success; do
  calls=0
  waits=''
  status=0
  retry_registry "$scenario" fake_command || status=$?
  case "$scenario" in
    recovery) [ "$calls" -eq 2 ] && [ "$status" -eq 0 ] && [ "$waits" = ' 30' ] ;;
    persistent) [ "$calls" -eq 4 ] && [ "$status" -eq 8 ] && [ "$waits" = ' 30 60 120' ] ;;
    compilation) [ "$calls" -eq 1 ] && [ "$status" -eq 9 ] && [ -z "$waits" ] ;;
    missing) [ "$calls" -eq 1 ] && [ "$status" -eq 10 ] && [ -z "$waits" ] ;;
    success) [ "$calls" -eq 1 ] && [ "$status" -eq 0 ] && [ -z "$waits" ] ;;
  esac || { printf 'FAIL: %s\n' "$scenario" >&2; exit 1; }
  printf 'PASS: %s\n' "$scenario"
done
