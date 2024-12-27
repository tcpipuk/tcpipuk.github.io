# Deploying Conduwuit with Docker

This guide covers deploying Conduwuit using Docker and Docker Compose, with several options for
reverse proxy configurations.

## Container Images

Official Conduwuit images are available from GitHub's container registry:

| Image                                | Notes                                          |
|--------------------------------------|------------------------------------------------|
| ghcr.io/girlbossceo/conduwuit:latest | Stable releases, recommended for production    |
| ghcr.io/girlbossceo/conduwuit:main   | Latest features, suitable for personal servers |

While the `:latest` tag is recommended for production use, the `:main` tag provides access to the
latest features and fixes. The main branch undergoes significant testing before changes are merged,
making it reliable for personal use while not necessarily "stable" for production environments.

## Quick Start

The simplest way to run Conduwuit is with a basic Docker command:

```bash
docker run -d -p 8448:6167 \
    -v db:/var/lib/conduwuit/ \
    -e CONDUWUIT_SERVER_NAME="your.server.name" \
    -e CONDUWUIT_ALLOW_REGISTRATION=false \
    --name conduwuit ghcr.io/girlbossceo/conduwuit:latest
```

However, for production deployments, we recommend using Docker Compose for better maintainability.

## Docker Compose Deployment

We provide several Docker Compose templates depending on your reverse proxy preference:

1. **Basic Setup** - For use with any reverse proxy
2. **Traefik Integration** - Two options:
   - For existing Traefik installations
   - Complete setup including Traefik
3. **Caddy Integration** - Ready-to-use setup with Caddy

### Basic Setup

Create a `docker-compose.yml` file:

```yaml:docker-compose.yml
version: '3.8'

services:
  conduwuit:
    image: ghcr.io/girlbossceo/conduwuit:latest
    restart: unless-stopped
    volumes:
      - ./data:/var/lib/conduwuit
    environment:
      - CONDUWUIT_SERVER_NAME=example.com
      - CONDUWUIT_ALLOW_REGISTRATION=false
      - CONDUWUIT_DATABASE_BACKEND=rocksdb
      - CONDUWUIT_DATABASE_PATH=/var/lib/conduwuit/db
    ports:
      - "6167:6167"
```

### Well-Known Setup

For federation to work properly, you'll need to serve `.well-known` files. This can be handled by
your reverse proxy, but we provide a simple Nginx container to serve these files if needed:

```yaml:docker-compose.yml
  well-known:
    image: nginx:alpine
    restart: unless-stopped
    volumes:
      - ./well-known:/usr/share/nginx/html/.well-known
    ports:
      - "8080:80"
```

Create the well-known files:

```bash
mkdir -p well-known/matrix
```

```json:well-known/matrix/server
{
    "m.server": "example.com:443"
}
```

```json:well-known/matrix/client
{
    "m.homeserver": {
        "base_url": "https://example.com"
    }
}
```

## Starting the Server

Once you've chosen and configured your setup:

```bash
# Start the services
docker compose up -d

# View the logs
docker compose logs -f
```

## Configuration Options

Conduwuit can be configured either through environment variables or a config file. Environment
variables take precedence over the config file.

Common environment variables include:

```yaml
CONDUWUIT_SERVER_NAME: "example.com"
CONDUWUIT_ALLOW_REGISTRATION: "false"
CONDUWUIT_DATABASE_BACKEND: "rocksdb"
CONDUWUIT_DATABASE_PATH: "/var/lib/conduwuit/db"
CONDUWUIT_PORT: "6167"
```

For a complete list of configuration options, see the [Configuration](config.md) guide.

## Next Steps

- Configure your chosen [reverse proxy](reverse-proxies/README.md)
- Review the [configuration options](config.md) for additional settings
- Consider setting up [TURN](https://conduwuit.puppyirl.gay/deploying/turn.html) for voice/video calls
