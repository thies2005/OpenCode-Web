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
- All auth is handled at the gateway level — the app itself runs unauthenticated internally

## Deployment on Coolify

### 1. Create the service

1. In Coolify, create a new **Private Resource** or **Public Repository** pointing to `https://github.com/thies2005/OpenCode-Web`
2. Set the branch to `main`
3. Under **Build Settings**, make sure the build mode is set to **Docker Compose**
4. Under **Network**, set the proxy to **Traefik**

### 2. Configure environment variables

| Variable | Required | Description |
|---|---|---|
| `OPENCODE_SERVER_URL` | Yes | Your OpenCode server URL (e.g. `https://opencode.schuelken.uk`) |
| `BASIC_AUTH_USERS` | Yes | htpasswd-formatted credentials (see below) |

### 3. Set up Basic Authentication

Generate an htpasswd string with your desired username and password:

```bash
htpasswd -nb myuser mysecretpassword
```

Output example:
```
myuser:$apr1$zD3B8X2V$k8T9QmF2vXcWnYjZpLqRO0
```

Add this as the `BASIC_AUTH_USERS` environment variable in Coolify's service settings.

**Important — escaping `$` signs in Coolify:**

Coolify uses Docker Compose variable substitution, which interprets `$` as variable expansion. You must double all `$` characters in the htpasswd hash when entering it in the Coolify UI:

```
myuser:$$apr1$$zD3B8X2V$$k8T9QmF2vXcWnYjZpLqRO0
```

### 4. Deploy

Click **Deploy** in Coolify. On first deploy the container will build (installing OpenCode takes a few minutes). Subsequent deploys will be faster due to Docker layer caching.

## How Authentication Works

Authentication is handled entirely by Traefik's Basic Auth middleware at the reverse proxy level. This approach was chosen over OpenCode's built-in `OPENCODE_SERVER_PASSWORD` for two reasons:

1. **WebSocket compatibility** — When OpenCode's internal auth is enabled, the browser doesn't consistently send credentials in WebSocket upgrade requests (`wss://`), causing 401 errors and terminal failures. Traefik handles this seamlessly because the browser caches the `Authorization: Basic` header after the initial popup and sends it on every request to the origin, including WebSocket handshakes.

2. **Single sign-on** — The user authenticates once via the browser's native Basic Auth popup. All subsequent requests (static assets, API calls, WebSocket connections) are automatically authenticated by Traefik without any additional prompts.

**Do not** set `OPENCODE_SERVER_PASSWORD` — it will conflict with the Traefik middleware and cause WebSocket 401 errors.

## Docker Compose Labels Explained

```yaml
labels:
  # Enable Traefik for this container
  - "traefik.enable=true"

  # Tell Coolify which port the app listens on
  - "coolify.port=4096"

  # Inject our auth middleware into Coolify's auto-generated Traefik router
  - "coolify.traefik.middlewares=opencode-auth"

  # Define the Basic Auth middleware — reads htpasswd users from env var
  - "traefik.http.middlewares.opencode-auth.basicauth.users=${BASIC_AUTH_USERS}"

  # Remove the Authorization header before forwarding to the app
  # Prevents the app from seeing proxy credentials
  - "traefik.http.middlewares.opencode-auth.basicauth.removeheader=true"
```

The `coolify.traefik.middlewares` label is the key difference from previous attempts. It attaches the middleware to Coolify's own generated router rather than defining a separate Traefik router label, which would conflict with Coolify's internal routing and cause 503 errors.

## Persistent Storage

Four named volumes preserve state across container restarts and redeployments:

| Volume | Mount Path | Purpose |
|---|---|---|
| `opencode-config` | `/root/.config/opencode` | OpenCode configuration files |
| `opencode-local` | `/root/.local/share/opencode` | Local data store and cache |
| `opencode-home` | `/root/.opencode` | OpenCode CLI installation and settings |
| `workspace` | `/workspace` | User files and project workspace |

To access the workspace from your host, find the volume using `docker volume inspect` and mount it, or use Coolify's volume mapping in the service settings.

## Updating OpenCode

To update OpenCode to the latest version, trigger a **Force Redeploy** in Coolify. This will rebuild the Docker image from the latest base Ubuntu packages and re-run the OpenCode installer script (`curl -fsSL https://opencode.ai/install | bash`).

## Troubleshooting

### 503 Service Unavailable

- Ensure the container is running: check Coolify's service logs
- Make sure the `coolify` external network exists (Coolify creates it automatically)
- Do not use manual `traefik.http.routers.*` labels — they conflict with Coolify's auto-generated routers. Use `coolify.traefik.middlewares` instead.

### Terminal not working (ENOENT)

- The Dockerfile installs `bash` and `procps` and sets `ENV SHELL=/bin/bash`
- If you modified the Dockerfile, ensure bash is available at `/bin/bash`
- Try a force redeploy to rebuild the image from scratch

### Auth popup keeps appearing

- The `removeheader=true` label strips the `Authorization` header before it reaches the app, so internal auth should not interfere
- Make sure `OPENCODE_SERVER_PASSWORD` is **not** set
- Clear browser cache and cookies for the domain, then re-authenticate

### Wrong password / auth not working

- Regenerate the htpasswd hash and double all `$` signs when pasting into Coolify
- Verify the `BASIC_AUTH_USERS` env var is set (not empty) — Coolify will fail to start the container if it's missing due to the variable substitution
