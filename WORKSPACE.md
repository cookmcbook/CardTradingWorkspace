# Card Trading Workspace

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

From an Android emulator, use `http://10.0.2.2:8082` and `http://10.0.2.2:8080` instead of `localhost`.

## CI shape

CI checks out the three repositories into sibling directories, starts this workspace's Compose stack, waits for health checks, builds/installs the mobile app, and runs Maestro. Pin service refs in CI when reproducible builds are required rather than always pulling the default branches.
