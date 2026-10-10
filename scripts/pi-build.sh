#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root_dir"

run_tests=0
case "${1:-}" in
  "") ;;
  --test) run_tests=1 ;;
  *) echo "Usage: $0 [--test]" >&2; exit 2 ;;
esac

if [[ ! -f .env ]]; then
  echo "Missing .env; copy .env.example and set Pi media settings first." >&2
  exit 1
fi
for key in MEDIA_S3_ACCESS_KEY MEDIA_S3_SECRET_KEY MEDIA_S3_PUBLIC_ENDPOINT; do
  if ! grep -Eq "^${key}=.+$" .env; then
    echo "Missing or empty ${key} in .env." >&2
    exit 1
  fi
done

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "Refusing to pull with tracked changes in the root checkout." >&2
  exit 1
fi

git pull --ff-only
bash scripts/checkout-services.sh
sudo docker compose -f docker-compose.yml -f compose.pi.yaml config -q
sudo docker compose --parallel 1 -f docker-compose.yml -f compose.pi.yaml build

if (( run_tests )); then
  sudo docker compose -f docker-compose.yml -f compose.pi.yaml --profile test run --build --rm backend-media-tests
fi

echo "Pi images built. Application services were not started or restarted."
echo "Deploy separately with: sudo docker compose -f docker-compose.yml -f compose.pi.yaml up -d --build"
