# Configuring Caddy for Conduwuit

This guide covers setting up Caddy as a reverse proxy for Conduwuit. Caddy is recommended for new
users as it handles TLS certificates automatically with sensible defaults.

1. [Basic Configuration](#basic-configuration)
2. [Vanity Domain Configuration](#vanity-domain-configuration)
3. [Matrix Homeserver Configuration](#matrix-homeserver-configuration)
4. [Verification](#verification)

## Basic Configuration

First, ensure Caddy is configured to use the DNS challenge for your certificates if you want
to use a wildcard certificate. Otherwise, it will obtain individual certificates as needed.

## Vanity Domain Configuration

The main domain (server.name) needs to serve Matrix well-known files on the standard HTTPS port
(443). This allows other Matrix servers to discover your homeserver's location:

```caddyfile:Caddyfile
server.name {
    # Matrix client-server well-known
    handle /.well-known/matrix/client {
        respond `{
            "m.homeserver": {
                "base_url": "https://matrix.server.name"
            },
            "org.matrix.msc3575.proxy": {
                "url": "https://matrix.server.name"
            }
        }` 200 {
            header Content-Type application/json
            header Access-Control-Allow-Origin *
        }
    }

    # Matrix server-server well-known
    handle /.well-known/matrix/server {
        respond `{
            "m.server": "matrix.server.name:443"
        }` 200 {
            header Content-Type application/json
        }
    }

    # Matrix Support contact information (MSC1929)
    handle /.well-known/matrix/support {
        respond `{
            "contacts": [
                {
                    "matrix_id": "@admin:server.name",
                    "email_address": "admin@server.name",
                    "role": "m.role.admin"
                }
            ]
        }` 200 {
            header Content-Type application/json
            header Access-Control-Allow-Origin *
        }
    }

    # Return 404 for all other paths
    handle /* {
        respond "Not Found" 404
    }
}
```

## Matrix Homeserver Configuration

If we make the homeserver accessible via both the delegated subdomain (matrix.server.name) as well
as through your Matrix domain on the default Matrix federation port (8448), then this will ensure
federation works even if well-known discovery fails:

```caddyfile:Caddyfile
matrix.server.name, server.name:8448 {
    # Proxy all Matrix traffic to Conduwuit
    handle /* {
        reverse_proxy unix//run/conduwuit/conduwuit.sock {
            transport unix {
                # Disable buffering for immediate data transfer
                buffer_size 0
            }
        }
    }

    # Compression for JSON responses
    encode gzip
}
```

## Verification

To verify your configuration:

```bash
# Test the configuration
caddy validate

# Reload if the test passes
caddy reload

# Test the well-known endpoints
curl https://server.name/.well-known/matrix/server
curl https://server.name/.well-known/matrix/client
curl https://server.name/.well-known/matrix/support

# Test the Matrix API
curl https://matrix.server.name/_matrix/federation/v1/version
```

You can also use the [Matrix Federation Tester](https://federationtester.matrix.org/) to verify
your server can communicate with other homeservers.
