#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="${HOME:-/home/pi}/.local/state/cardtrading-push-build"
STATE_FILE="$STATE_DIR/successful-refs"
MODE="${1:-}"
case "$MODE" in ""|--check) ;; *) echo "Usage: $0 [--check]" >&2; exit 2 ;; esac
mkdir -p "$STATE_DIR"
exec 9>"$STATE_DIR/lock"
if ! flock -n 9; then echo "Another Pi build check is active; skipping."; exit 0; fi
cd "$ROOT_DIR"
for file in docker-compose.yml compose.pi.yaml; do
  if ! git diff --quiet -- "$file" || ! git diff --cached --quiet -- "$file"; then
    echo "Refusing to build with local changes to $file." >&2; exit 1
  fi
done
if [[ ! -f .env ]]; then echo "Missing .env; refusing to build." >&2; exit 1; fi
for key in MEDIA_S3_ACCESS_KEY MEDIA_S3_SECRET_KEY MEDIA_S3_PUBLIC_ENDPOINT; do
  if ! grep -Eq "^${key}=.+$" .env; then echo "Missing or empty $key in .env; refusing to build." >&2; exit 1; fi
done
REPOS=(CardTradingBackend AuthenticationService CardTradingPOC)
EXPECTED_UPSTREAMS=(origin/main origin/main origin/master)
declare -a PATHS UPSTREAMS LOCAL_SHAS REMOTE_SHAS
for i in "${!REPOS[@]}"; do
  name="${REPOS[$i]}"; path="$ROOT_DIR/$name"
  if [[ ! -d "$path/.git" ]]; then echo "Missing Git checkout: $path" >&2; exit 1; fi
  if [[ -n "$(git -C "$path" status --porcelain=v1 --untracked-files=all)" ]]; then
    echo "Refusing to update $name: local tracked or untracked work exists." >&2; exit 1
  fi
  upstream="$(git -C "$path" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}')"
  if [[ "$upstream" != "${EXPECTED_UPSTREAMS[$i]}" ]]; then
    echo "Refusing to watch $name: expected ${EXPECTED_UPSTREAMS[$i]}, found $upstream." >&2; exit 1
  fi
  PATHS[$i]="$path"; UPSTREAMS[$i]="$upstream"
done
for i in "${!REPOS[@]}"; do
  git -C "${PATHS[$i]}" fetch --quiet origin
  LOCAL_SHAS[$i]="$(git -C "${PATHS[$i]}" rev-parse HEAD)"
  REMOTE_SHAS[$i]="$(git -C "${PATHS[$i]}" rev-parse "${UPSTREAMS[$i]}")"
  if ! git -C "${PATHS[$i]}" merge-base --is-ancestor "${LOCAL_SHAS[$i]}" "${REMOTE_SHAS[$i]}"; then
    echo "Refusing non-fast-forward update in ${REPOS[$i]}; local work is preserved." >&2; exit 1
  fi
done
desired_file="$(mktemp "$STATE_DIR/.refs.XXXXXX")"
trap 'rm -f "$desired_file"' EXIT
for i in "${!REPOS[@]}"; do printf '%s %s\n' "${REPOS[$i]}" "${REMOTE_SHAS[$i]}" >> "$desired_file"; done
if [[ "$MODE" == "--check" ]]; then
  for i in "${!REPOS[@]}"; do
    if [[ "${LOCAL_SHAS[$i]}" != "${REMOTE_SHAS[$i]}" ]]; then echo "Pending fast-forward: ${REPOS[$i]} -> ${REMOTE_SHAS[$i]:0:12}"; fi
  done
  if [[ -f "$STATE_FILE" ]] && cmp -s "$desired_file" "$STATE_FILE"; then echo "Refs match the last successful build."
  elif [[ -f "$STATE_FILE" ]]; then echo "A build would run for the current refs."
  else echo "No success record yet; the first scheduled run will build once."; fi
  exit 0
fi
for i in "${!REPOS[@]}"; do
  if [[ "${LOCAL_SHAS[$i]}" != "${REMOTE_SHAS[$i]}" ]]; then
    echo "Fast-forwarding ${REPOS[$i]} to ${REMOTE_SHAS[$i]:0:12}"
    git -C "${PATHS[$i]}" merge --ff-only "${REMOTE_SHAS[$i]}"
  fi
done
if [[ -f "$STATE_FILE" ]] && cmp -s "$desired_file" "$STATE_FILE"; then echo "No new service commits since the last successful build."; exit 0; fi
echo "Service refs changed; validating Compose and building Pi images serially."
sudo -n docker compose -f docker-compose.yml -f compose.pi.yaml config -q
sudo -n docker compose --parallel 1 -f docker-compose.yml -f compose.pi.yaml build
mv "$desired_file" "$STATE_FILE"
trap - EXIT
echo "Pi images built successfully. App containers were not started or restarted."
