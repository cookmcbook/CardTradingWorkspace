# Raspberry Pi ARMv7 build and staging

The default Compose setup remains unchanged for ordinary development. Use the optional `compose.pi.yaml` overlay on the Pi; it selects ARMv7 images, SeaweedFS for S3-compatible listing media, and the separate `CardTradingPOC/server/Dockerfile.armv7` Node 22 image.

## One-time setup

1. Copy `.env.example` to `.env` and set `MEDIA_S3_ACCESS_KEY`, `MEDIA_S3_SECRET_KEY`, and `MEDIA_S3_PUBLIC_ENDPOINT`. The public endpoint must be reachable by clients opening signed listing-image URLs. Keep `.env` private and uncommitted.
2. Use Docker Compose v2 with `!reset`/`!override` support and authenticate Git for the service repositories.

## Pull and build

From the workspace root:

```bash
./scripts/pi-build.sh
```

The script fast-forwards this workspace and its service checkouts to their configured default branches, validates the merged Compose configuration, and builds the Pi images serially. It does **not** start or restart the application services. Add `--test` to run the backend media tests; that test run may start the SeaweedFS dependency.

```bash
./scripts/pi-build.sh --test
```

## Deploy intentionally

After reviewing the build, start or update the services with:

```bash
sudo docker compose -f docker-compose.yml -f compose.pi.yaml up -d --build
```

The Compose host ports remain bound to loopback. This setup does not configure Tailscale Serve or expose services on the LAN.
## Automatic builds after service pushes

The Pi polls the service repositories' default branches every five minutes using the `cardtrading-push-build.timer` systemd timer. It watches `CardTradingBackend/main`, `AuthenticationService/main`, and `CardTradingPOC/master`; after a push, it fast-forwards only clean checkouts and builds the Compose images serially. This is polling (not an instant webhook), adds no inbound endpoint, and does not start or restart app containers. Failed builds retry on the next timer run because the success record is written only after a successful build. Dirty or diverged checkouts stop safely without resets.

Install/update the checked-in units on the Pi with:

```bash
sudo install -m 0644 ops/systemd/cardtrading-push-build.service /etc/systemd/system/
sudo install -m 0644 ops/systemd/cardtrading-push-build.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now cardtrading-push-build.timer
```

Inspect activity with `sudo systemctl status cardtrading-push-build.timer` and `sudo journalctl -u cardtrading-push-build.service -n 100`. To disable polling, run `sudo systemctl disable --now cardtrading-push-build.timer`. Run `./scripts/pi-watch-build.sh --check` to fetch refs and preview pending work without fast-forwarding or building.
