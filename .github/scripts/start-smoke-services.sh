#!/usr/bin/env sh
# Pull service images and build one service at a time. BuildKit may still fetch
# stages within a single Dockerfile concurrently; this avoids cross-service bursts.
set -eu
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$script_dir/retry-registry.sh"
retry_registry pull docker compose --parallel 1 pull --ignore-buildable
for service in auth battle-verifier match-service backend; do
  retry_registry "build-$service" docker compose --parallel 1 --progress plain build "$service"
done
# Everything is now local. Startup must not implicitly pull or rebuild images.
docker compose --parallel 1 up -d --no-build --pull never
