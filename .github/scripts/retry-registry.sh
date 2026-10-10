#!/usr/bin/env sh
# Source this helper. Retry Docker registry throttling only, never general build
# failures (including npm/Maven HTTP 429s). Preserve each attempt for diagnostics.
retry_registry() {
  registry_label=$1
  shift
  registry_attempt=1
  registry_log_dir=${REGISTRY_LOG_DIR:-artifacts/backend-build}
  mkdir -p "$registry_log_dir"
  while :; do
    registry_log="$registry_log_dir/$registry_label-attempt-$registry_attempt.log"
    printf 'Running %s (attempt %s/4)\n' "$registry_label" "$registry_attempt"
    if "$@" > "$registry_log" 2>&1; then
      cat "$registry_log"
      return 0
    else
      registry_status=$?
    fi
    cat "$registry_log"
    # Require throttling on a registry/pull error line, not just anywhere in a
    # build log that happened to mention Docker Hub during a successful pull.
    if ! grep -Ei 'registry-1\.docker\.io|failed to resolve source metadata|manifest.*(request|fetch)|toomanyrequests|pull rate limit|Error response from daemon' "$registry_log" |
      grep -Eiq '429|too many requests|toomanyrequests|pull rate limit'; then
      printf 'Non-registry failure in %s; not retrying.\n' "$registry_label" >&2
      return "$registry_status"
    fi
    if [ "$registry_attempt" -ge 4 ]; then
      printf 'Registry throttling persisted after four attempts. Configure Docker Hub credentials or retry later.\n' >&2
      return "$registry_status"
    fi
    registry_delay=$((30 * (1 << (registry_attempt - 1))))
    printf 'Registry throttled %s; waiting %ss before retrying.\n' "$registry_label" "$registry_delay"
    sleep "$registry_delay"
    registry_attempt=$((registry_attempt + 1))
  done
}
