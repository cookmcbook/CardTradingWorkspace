# CardTrading Workspace

This repository is the local orchestration workspace for three separate service repositories:

- `CardTradingPOC` — Expo/React Native mobile client
- `CardTradingBackend` — game API
- `AuthenticationService` — authentication API

The service repositories are intentionally kept independent. The workspace owns Docker Compose, local infrastructure, and CI orchestration.

## Bootstrap

Set the repository URLs in `scripts/checkout-services.ps1` or `scripts/checkout-services.sh`, then run the appropriate script from this directory. For private repositories, authenticate Git before running it.

Copy `.env.example` to `.env` and provide the local JWT key values, then start infrastructure and services:

```powershell
docker compose up -d --build
```

The services are exposed to the host at:

- AuthenticationService: `http://localhost:8082`
- CardTradingBackend: `http://localhost:8080`
- Local S3-compatible media endpoint: `http://localhost:9000`

From an Android emulator, use `http://10.0.2.2:8082` and `http://10.0.2.2:8080` instead of `localhost`.

## Raspberry Pi ARMv7 build

Use the optional `compose.pi.yaml` overlay for ARMv7 hardware; the default Compose setup remains suitable for ordinary development. The overlay uses SeaweedFS for S3-compatible listing media and the separate `CardTradingPOC/server/Dockerfile.armv7` Node 22 image.

Copy `.env.example` to `.env` and set `MEDIA_S3_ACCESS_KEY`, `MEDIA_S3_SECRET_KEY`, and `MEDIA_S3_PUBLIC_ENDPOINT`. Keep `.env` private and uncommitted. From the workspace root, `./scripts/pi-build.sh` fast-forwards the workspace and service checkouts, validates Compose, and builds the Pi images without starting or restarting the application services. Add `--test` to run the backend media tests; SeaweedFS may be started as a test dependency.

To deploy intentionally, run `sudo docker compose -f docker-compose.yml -f compose.pi.yaml up -d --build`. Compose host ports remain bound to loopback; Tailscale Serve is a separate configuration and is not changed by this setup.

## CI shape

CI checks out the three repositories into sibling directories, starts this workspace's Compose stack, waits for health checks, builds/installs the mobile app, and runs Maestro. Pin service refs in CI when reproducible builds are required rather than always pulling the default branches.
