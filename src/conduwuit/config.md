# Configuring Conduwuit

This guide covers the essential Conduwuit configuration options for Docker deployments. For a
complete reference, see the [example configuration file](https://github.com/girlbossceo/conduwuit/blob/main/conduwuit-example.toml).

## Example Configuration

Start by downloading the example configuration file which includes comprehensive documentation for
all available options:

```bash
curl -o data/conduwuit.toml https://raw.githubusercontent.com/girlbossceo/conduwuit/main/conduwuit-example.toml
```

## Core Settings

These are the only required settings:

```toml:conduwuit.toml
[global]
# Your server's domain name (required)
server_name = "server.name"

# Trusted servers for key verification (recommended)
trusted_servers = ["envs.net", "beeper.com", "matrix.org"]
```

## Connection Settings

Choose between TCP ports or Unix sockets:

```toml:conduwuit.toml
# TCP Configuration
port = 6167
address = "0.0.0.0"  # For Docker

# Or Unix Socket Configuration (recommended when possible)
unix_socket_path = "/run/conduwuit/conduwuit.sock"
unix_socket_perms = 666
```

**Note:** If you're using Unix sockets, you'll need to ensure the `port` and `address` settings are
commented out or you'll get an error when Conduwuit launches.

## Federation and Security

```toml:conduwuit.toml
# Federation Controls
allow_federation = true
allow_public_room_directory_over_federation = true
allow_profile_lookup_federation_requests = true

# Registration Controls
allow_registration = true
registration_token = "your-secure-token-here"

# Privacy Settings
allow_device_name_federation = false
allow_legacy_media = false  # Enable to allow older clients and servers to load media
```

You can generate a secure registration token using this command:

```bash
# Generate a 64-character random token
openssl rand -base64 48 | tr -d '/+' | cut -c1-64
```

## Performance Tuning

In practice, I've found requiring DNS over TCP is the best way to run Conduwuit, as it can easily
DNS resolvers with UDP, and TCP offers a higher level of reliability.

If you want to do this, you can set the cache high to save repeated lookups, and increase the
timeout to allow the batched lookups over TCP to do their thing:

```toml:conduwuit.toml
# DNS Optimisation
dns_cache_entries = 1_000_000
dns_timeout = 60
query_over_tcp_only = true
```

## Presence and Real-time Features

Conduwuit is extremely performant over federation, so these options should perform very well, but
you can choose whether or not you want them for performance or privacy reasons:

```toml:conduwuit.toml
# Presence Settings
allow_local_presence = true
allow_incoming_presence = true
allow_outgoing_presence = true

# Typing Indicators
allow_outgoing_typing = true
allow_incoming_typing = true
```

## URL Preview Settings

URL previews are a great way to improve the user experience of your Matrix server, but they can
also be a source of abuse, so you can choose whether you want to use them here:

```toml:conduwuit.toml
# URL Preview Controls
url_preview_domain_contains_allowlist = ["*"]
url_preview_domain_explicit_allowlist = ["*"]
url_preview_url_contains_allowlist = ["*"]
url_preview_max_spider_size = 16_777_216
url_preview_check_root_domain = true
```

## Advanced Options

There are tons of other options available, including setting TURN servers for VoIP calling.

For detailed tuning of database performance, federation behaviour, or other advanced settings,
refer to the [example configuration file](https://raw.githubusercontent.com/girlbossceo/conduwuit/main/conduwuit-example.toml)
which includes comprehensive documentation for all available options.
