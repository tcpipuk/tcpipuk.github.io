# Configuring Reverse Proxies for Conduwuit

A reverse proxy is essential for running Conduwuit in production, handling TLS termination and
providing a secure interface to the internet. This section covers configuration for three popular
reverse proxies:

Before configuring your chosen reverse proxy, you'll need to [set up SSL certificates](ssl.md)
for your domains.

1. [Caddy](caddy.md) - Known for its simplicity and automatic HTTPS
2. [Nginx](nginx.md) - Popular for its performance and flexibility

Choose the guide that matches your preferred reverse proxy. All options will provide:

- TLS termination
- HTTP/2 support
- Proper header forwarding
- WebSocket support for live updates

If you're new to reverse proxies, Caddy might be the easier choice as it handles SSL certificates
automatically. If you're using Docker Compose, Traefik integrates particularly well with container
deployments. However, if you're already familiar with Nginx or need more fine-grained control,
the Nginx configuration will serve you well.
