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

We provide two main deployment patterns, depending on how you want to connect to your reverse proxy:

### TCP Port Configuration

This configuration exposes Conduwuit on a TCP port, suitable for when your reverse proxy is on a
different host or when using Kubernetes:

```yaml:docker-compose.yml
version: '3.8'

services:
  conduwuit:
    cpus: 3
    image: ghcr.io/girlbossceo/conduwuit:latest
    environment:
      CONDUWUIT_CONFIG: '/var/lib/conduwuit/conduwuit.toml'
    mem_limit: 4G
    ports:
      - "6167:6167"
    restart: unless-stopped
    volumes:
      - ./data:/var/lib/conduwuit
```

### Unix Socket Configuration

This configuration uses Unix sockets for improved performance when your reverse proxy is on the same
host:

```yaml:docker-compose.yml
version: '3.8'

services:
  conduwuit:
    cpus: 3
    image: ghcr.io/girlbossceo/conduwuit:latest
    environment:
      CONDUWUIT_CONFIG: '/var/lib/conduwuit/conduwuit.toml'
    mem_limit: 4G
    restart: unless-stopped
    volumes:
      - ./data:/var/lib/conduwuit
      - /run/conduwuit:/run/conduwuit
```

For both configurations, create a configuration file in the `data` directory:

```bash
curl -o data/conduwuit.toml https://raw.githubusercontent.com/girlbossceo/conduwuit/main/conduwuit-example.toml
```

See the [configuration guide](config.md) for more information on configuring Conduwuit, and the
[reverse proxy guide](reverse-proxies/README.md) for more information on how to set up a reverse
proxy to handle inbound connections to the server.

## Starting the Server

Once you've chosen and configured your setup:

```bash
# Start the services
docker compose up -d

# View the logs
docker compose logs -f
```
