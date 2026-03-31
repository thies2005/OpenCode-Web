# OpenCode-Web

Dockerized deployment of [OpenCode](https://opencode.ai) running in web mode on Ubuntu 24.04, designed to run behind [Coolify](https://coolify.io) with Traefik reverse proxy and Basic Authentication.

## Architecture

```
Browser --> Traefik (Coolify) --> OpenCode Web Container (port 4096)
                |
                +-- Basic Auth middleware (opencode-auth)
                +-- TLS termination
                +-- WebSocket proxy
```

- **OpenCode** serves its web UI and terminal on port `4096` inside the container
- **Traefik** (managed by Coolify) handles TLS, routing, and authentication
- Auth is handled at the gateway level — the app itself runs unauthenticated internally

## Deployment on Coolify

### 1. Create the service

1. In Coolify, create a new **Public Repository** pointing to `https://github.com/thies2005/OpenCode-Web`
2. Set the branch to `main`
3. Under **Build Settings**, make sure the build mode is set to **Docker Compose**
4. Under **Network**, set the proxy to **Traefik**

### 2. Configure environment variables

| Variable | Required | Description |
|---|---|---|
| `OPENCODE_BASIC_AUTH` | Yes | htpasswd-formatted credentials (see below) |

### 3. Set up Basic Authentication

Generate an htpasswd string with your desired username and password:

```bash
htpasswd -nbB myuser mysecretpassword
```

Output example:
```
myuser:$2y$12$ci.4U63YX83CwkyUrjqxAucnmi2xXOIlEF6T/KdP9824f1Rf1iyNG
```

Add this as the `OPENCODE_BASIC_AUTH` environment variable in Coolify's service settings.

**No need to escape `$` signs** — Docker Compose only substitutes `$` followed by valid variable names (letters/digits/underscores starting with a letter). bcrypt hash segments like `$2y$12$...` all start with digits, so they are treated as literal text.

### 4. Deploy

Click **Deploy** in Coolify. On first deploy the container will build (installing OpenCode takes a few minutes). Subsequent deploys will be faster due to Docker layer caching.

## How Authentication Works

Authentication is handled by Traefik's Basic Auth middleware at the reverse proxy level, following [Coolify's official docs](https://coolify.io/docs/knowledge-base/proxy/traefik/basic-auth).

1. **One browser popup** — The user authenticates once via the browser's native Basic Auth popup
2. **All requests covered** — The browser caches the `Authorization: Basic` header and sends it on every request, including WebSocket upgrade handshakes (terminal works seamlessly)

**Do not** also set `OPENCODE_SERVER_PASSWORD` — it conflicts with Traefik auth and causes WebSocket 401 errors.

## Docker Compose Labels

This follows [Coolify's official Traefik Basic Auth guide for Docker Compose services](https://coolify.io/docs/knowledge-base/proxy/traefik/basic-auth#docker-compose-and-services):

```yaml
labels:
  # Enable Traefik for this container
  - "traefik.enable=true"

  # Tell Coolify which port the app listens on
  - "coolify.port=4096"

  # Define the Basic Auth middleware — Coolify auto-discovers this
  - "traefik.http.middlewares.opencode-auth.basicauth.users=${OPENCODE_BASIC_AUTH}"
```

Coolify auto-discovers middleware labels defined in `docker-compose.yml` and attaches them to its auto-generated router. No manual router label or `coolify.traefik.middlewares` label is needed.

## Persistent Storage

Four named volumes preserve state across container restarts and redeployments:

| Volume | Mount Path | Purpose |
|---|---|---|
| `opencode-config` | `/root/.config/opencode` | OpenCode configuration files |
| `opencode-local` | `/root/.local/share/opencode` | Local data store and cache |
| `opencode-home` | `/root/.opencode` | OpenCode CLI installation and settings |
| `workspace` | `/workspace` | User files and project workspace |

## Updating OpenCode

Trigger a **Force Redeploy** in Coolify to rebuild the image with the latest OpenCode version.

## Troubleshooting

### 503 Service Unavailable

- Ensure the container is running: check Coolify's service logs
- Make sure the `coolify` external network exists (Coolify creates it automatically)
- Do not use manual `traefik.http.routers.*` labels — they conflict with Coolify's auto-generated routers

### Auth not working

- Make sure `OPENCODE_BASIC_AUTH` is set in Coolify's environment variables
- Regenerate the hash using `htpasswd -nbB user password`
- Do not set `OPENCODE_SERVER_PASSWORD` (conflicts with Traefik auth)

### Terminal not working

- The Dockerfile installs `bash` and `procps` and sets `ENV SHELL=/bin/bash`
- Try a force redeploy to rebuild the image from scratch

### Doubled URL in browser

- Do not set `OPENCODE_SERVER_URL` — it causes the app to concatenate the URL with the current domain
