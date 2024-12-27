# Matrix Conduwuit Homeserver Guides

This section provides comprehensive guides for deploying Conduwuit, a featureful fork of the Conduit
Matrix homeserver. Written in Rust, Conduwuit aims to be a high-performance and efficient homeserver
that's easy to set up and "just works".

## Quick Start

These Docker guides will walk you through:

1. [Docker Deployment](docker.md) - Set up the Conduwuit container
2. [Server Configuration](config.md) - Configure your homeserver
3. [Reverse Proxies](reverse-proxies/README.md) - Set up external access
   - [SSL Certificates](reverse-proxies/ssl.md) - Secure your server
   - Choose your proxy:
     - [Caddy](reverse-proxies/caddy.md) - Simple, automatic HTTPS
     - [Nginx](reverse-proxies/nginx.md) - Popular and flexible

## Deployment Options

While these guides focus on Docker deployment, Conduwuit provides several installation options:

- **Docker containers** (covered in this guide)
- **Debian packages** (.deb) for x86_64 and ARM64
- **Static binaries** for Linux (x86_64/ARM64) and macOS (x86_64/ARM64)

You can find all these options in the [official releases](https://github.com/girlbossceo/conduwuit/releases).
For non-Docker deployments, refer to the [generic deployment guide](https://conduwuit.puppyirl.gay/deploying/generic.html)
which covers setting up users, systemd services, and more.

Conduwuit is quite stable and very usable as a daily driver for low-medium sized homeservers. While
technically in Beta (inherited from Conduit), this status is becoming less relevant as the codebase
significantly diverges from upstream Conduit.

Key features and differences from Conduit:

- Written in Rust for high performance and memory efficiency
- Complete drop-in replacement for Conduit (when using RocksDB)
- Single-process architecture (no worker configuration needed)
- Actively maintained with regular updates
- Designed for stability and real-world use

## Getting Help

If you need assistance, you can join these Matrix rooms:

- [#conduwuit:puppygock.gay](https://matrix.to/#/#conduwuit:puppygock.gay) -
  Main support and discussion
- [#conduwuit-offtopic:girlboss.ceo](https://matrix.to/#/#conduwuit-offtopic:girlboss.ceo) -
  Community chat
- [#conduwuit-dev:puppygock.gay](https://matrix.to/#/#conduwuit-dev:puppygock.gay) -
  Development discussion

Please review our [Community Code of Conduct](https://conduwuit.puppyirl.gay/conduwuit_coc.html)
before participating in these rooms.

## Try It Out

You can try Conduwuit on the official instance at `transfem.dev`, which provides both
[Element](https://element.transfem.dev) and [Cinny](https://cinny.transfem.dev) web clients.
This is a public homeserver listed on [servers.joinmatrix.org](https://servers.joinmatrix.org),
so please review the rules at [transfem.dev/homeserver_rules.txt](https://transfem.dev/homeserver_rules.txt)
before registering.

Let's get started with deploying your own efficient Matrix homeserver!
