# OpenCode-Web Deployment History & Learnings

This document summarizes the deployment process, challenges, and solutions encountered during the setup of OpenCode-Web on Coolify.

## 1. Project Overview
The goal was to deploy [OpenCode-Web](https://github.com/thies2005/OpenCode-Web) as a Dockerized application on a Coolify server, ensuring persistent storage and authenticated access.

## 2. Key Challenges & Solutions

### A. Terminal Shell Accessibility (`ENOENT`)
- **Issue**: The OpenCode web terminal failed to launch with `ENOENT: posix_spawn '/bin/bash'`.
- **Cause**: Pathing differences in Ubuntu 24.04 and internal app assumptions about shell locations.
- **Solution**: 
  - Standardized the Dockerfile on `ubuntu:24.04`.
  - Installed `bash` and `procps`.
  - Explicitly set `ENV SHELL=/bin/bash`.
  - Ensured the build uses the latest image via "Force Redeploy".

### B. Authentication & WebSocket 401s
- **Issue**: Internal authentication (`OPENCODE_SERVER_PASSWORD`) caused WebSocket handshake failures (401 Unauthorized) because the browser wouldn't consistently send credentials in the `wss://` URI.
- **Solution**: 
  - Moved authentication to the **Gateway level** (Traefik Basic Auth).
  - Disabled internal app auth to prevent credential conflicts.
  - This allows the browser to authenticate once via a standard popup, after which Traefik handles all sub-requests (static files, WebSockets) seamlessly.

### C. Docker Compose Escaping
- **Issue**: Dollar signs (`$`) in bcrypt hashes were being misinterpreted by Docker Compose as environment variables.
- **Solution**: 
  - Escaped all dollar signs in the password hash by doubling them (`$$`) in the Coolify environment variable UI.
  - Final hash format: `opencode:$$2a$$10$$...`

### D. Reverse Proxy (Traefik) Routing (503 Errors)
- **Issue**: Manual Traefik labels in `docker-compose.yml` often conflicted with Coolify's internal router generation, resulting in `503 Service Unavailable`.
- **Solution**: 
  - Switched to **Coolify shorthand labels**:
    - `coolify.port=4096`
    - `coolify.traefik.middlewares=opencode-auth`
  - This delegates the complex routing (TLS, Host rules) to Coolify while still allowing custom middleware injection.
  - Instructed user to set **Proxy: Traefik** in the UI to sync with these shorthands.

## 3. Persistent Storage
Four named volumes were configured to ensure state is preserved across container restarts:
- `opencode-config`: App configuration.
- `opencode-local`: Local data store.
- `opencode-home`: Home directory settings.
- `workspace`: User file workspace.

## 4. Final Configuration
The final setup uses a hardened Dockerfile with `tini` as the init process and a streamlined `docker-compose.yml` that leverages Coolify's native automation for proxy management.
