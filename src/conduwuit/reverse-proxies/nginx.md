# Configuring Nginx for Conduwuit

This guide covers setting up Nginx as a reverse proxy for Conduwuit, with optimisations for
performance and modern Matrix features.

1. [Basic Configuration](#basic-configuration)
2. [Vanity Domain Configuration](#vanity-domain-configuration)
3. [Matrix Homeserver Configuration](#matrix-homeserver-configuration)
4. [Verification](#verification)

## Basic Configuration

First, set up an upstream definition for Conduwuit. Using Unix sockets is recommended when both
Nginx and Conduwuit are on the same machine for improved performance:

```nginx:conf.d/upstreams.conf
upstream conduwuit_server {
    # Unix socket (recommended for same-machine deployments)
    server unix:/run/conduwuit/conduwuit.sock max_fails=0;
    
    # TCP alternative if needed
    #server 127.0.0.1:6167 max_fails=0;
    
    # Connection pooling
    keepalive 32;
    keepalive_requests 1000;
    keepalive_time 1h;
    keepalive_timeout 600s;
}
```

## Vanity Domain Configuration

The main domain (server.name) needs to serve Matrix well-known files on the standard HTTPS port
(443). This allows other Matrix servers to discover your homeserver's location:

```nginx:conf.d/server.name.conf
# Main domain for well-known files
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name server.name;

    # TLS Configuration
    ssl_certificate /etc/letsencrypt/live/server.name/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/server.name/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    # Logging (optional)
    access_log off;
    error_log off;

    # Matrix Server well-known
    location /.well-known/matrix/server {
        default_type application/json;
        add_header Access-Control-Allow-Origin "*";
        return 200 '{"m.server": "matrix.server.name:443"}';
    }

    # Matrix Client well-known (with sliding sync support)
    location /.well-known/matrix/client {
        default_type application/json;
        add_header Access-Control-Allow-Origin "*";
        return 200 '{"m.homeserver": {"base_url": "https://matrix.server.name"}, "org.matrix.msc3575.proxy": {"url": "https://matrix.server.name"}}';
    }

    # Matrix Support contact information (MSC1929)
    location /.well-known/matrix/support {
        default_type application/json;
        add_header Access-Control-Allow-Origin "*";
        return 200 '{"contacts": [{"matrix_id": "@admin:server.name", "email_address": "admin@server.name", "role": "m.role.admin"}]}';
    }

    # Optional: Return 404 for other URLs
    location / {
        return 404 "Not Found";
    }
}
```

**Note:** The well-known files help clients discover your server and provide important metadata,
update the domain names

## Matrix Homeserver Configuration

If we make the homeserver accessible via both the delegated subdomain (matrix.server.name) as well
as through your Matrix domain on the default Matrix federation port (8448), then this will ensure
federation works even if well-known discovery fails:

```nginx:conf.d/matrix.server.name.conf
# Matrix homeserver
server {
    listen 8448 ssl http2;
    listen [::]:8448 ssl http2;
    server_name matrix.server.name server.name;

    # TLS Configuration
    ssl_certificate /etc/letsencrypt/live/server.name/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/server.name/privkey.pem;
    include includes/common.conf;

    # Logging
    access_log /var/log/nginx/conduwuit-access.log;
    error_log /var/log/nginx/conduwuit-error.log;

    # Security Headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Content-Type-Options nosniff;
    add_header X-Frame-Options DENY;
    add_header X-XSS-Protection "1; mode=block";

    # Disable buffering for immediate data transfer
    proxy_buffering off;

    # Compression for JSON responses
    gzip on;
    gzip_types application/json;
    gzip_min_length 1000;

    # Matrix API endpoints
    location /_matrix/ {
        # Proxy settings
        proxy_pass http://conduwuit_server;

        # Proxy Settings
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Proxy timeouts
        proxy_read_timeout 60s;
        proxy_send_timeout 60s;
    }
}
```

## Verification

To verify your configuration:

```bash
# Test the Nginx configuration
nginx -t

# Reload if the test passes
systemctl reload nginx

# Test the well-known endpoints
curl https://server.name/.well-known/matrix/server
curl https://server.name/.well-known/matrix/client
curl https://server.name/.well-known/matrix/support

# Test the Matrix API
curl https://matrix.server.name/_matrix/federation/v1/version
```

You can also use the [Matrix Federation Tester](https://federationtester.matrix.org/) to verify
your server can communicate with other homeservers.
