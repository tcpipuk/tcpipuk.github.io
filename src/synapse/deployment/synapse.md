# Deploying a Synapse Homeserver with Docker

## 2. Synapse Configuration

1. [Default File](#default-file)
2. [Log Config](#log-config)
3. [Homeserver Config](#homeserver-config)
4. [Cache Optimisation](#cache-optimisation)

### Default File

Before we can modify the Synapse config, we need to create it.

Run this command to launch Synapse only to generate the config file and then close again:

```bash
docker compose run -it synapse generate && docker compose down -v
```

In your "synapse" directory you should now find a number of files like this:

```bash
/synapse# ls -lh
total 16K
-rw-r--r-- 1 root root  694 Dec 20 23:20 mydomain.com.log.config
-rw-r--r-- 1 root root   59 Dec 20 23:20 mydomain.com.signing.key
-rw-r--r-- 1 root root 1.3K Dec 20 23:20 homeserver.yaml
```

The signing key is unique to your server and is vital to maintain for other servers to trust yours
in the future. You can wipe the entire database and still be able to federate with other servers if
your signing key is the same, so it's worthwhile backing this up now.

### Log Config

For the log config, by default this is very barebones and just logs straight to console, but you
could replace it with something like this to keep a daily log for the past 3 days in your `logs`
folder:

```yaml,filepath=mydomain.com.log.config
version: 1
formatters:
  precise:
    format: '%(asctime)s - %(name)s - %(lineno)d - %(levelname)s - %(request)s - %(message)s'

handlers:
  file:
    class: logging.handlers.TimedRotatingFileHandler
    formatter: precise
    filename: /logs/synapse.log
    when: midnight
    backupCount: 3
    encoding: utf8

  buffer:
    class: synapse.logging.handlers.PeriodicallyFlushingMemoryHandler
    target: file
    capacity: 10
    flushLevel: 30
    period: 5

loggers:
    synapse:
        level: INFO
        handlers: [buffer]
    synapse.storage.SQL:
        level: INFO
        handlers: [buffer]
    shared_secret_authenticator:
        level: INFO
        handlers: [buffer]

root:
    level: INFO
    handlers: [buffer]
```

### Homeserver Config

By default, this file is quite short and relies a lot on defaults. There is no harm adding blank
lines between entries here to make it more readable, or adding comments (starting with the `#` hash
character) to explain what lines mean.

**Note: The "secret" or "key" lines are unique to your server and things are likely to misbehave if
you change some of them after the server is running.** It's generally best to leave them safe at the
bottom of the file while you work on the other values.

Here's an example with comments you may wish to use to start with some safe defaults:

```yaml,filepath=homeserver.yaml
# Basic Server Details
server_name: "mydomain.com" # Domain name used by other homeservers to connect to you
public_baseurl: "https://matrix.mydomain.com/" # Public URL of your Synapse server
admin_contact: "mailto:admin@mydomain.com" # Contact email for the server admin
pid_file: "/data/process.pid" # File that stores the process ID of the Synapse server
signing_key_path: "/data/mydomain.com.signing.key" # Location of the signing key for the server

# Logging and Monitoring
log_config: "/data/log.config/synapse.log.config" # Path to the logging configuration file
report_stats: false # Whether to report anonymous statistics
enable_metrics: false # Enable the metrics listener to monitor with Prometheus

# Login and Registration
enable_registration: false # Whether to allow users to register on this server
enable_registration_captcha: true # Whether to enable CAPTCHA for registration
enable_registration_without_verification: false # Allow users to register without email verification
delete_stale_devices_after: 30d # Devices not synced in this long will have their tokens and pushers retired
password_config:
  enabled: true # Set to false to only allow SSO login

# Database and Storage Configuration
database:
  name: psycopg2 # PostgreSQL adapter for Python
  args:
    user: synapse # Username to login to Postgres
    password: SuperSecretPassword # Password for Postgres
    database: synapse # Name of the database in Postgres
    host: "/sockets" # Hostname of the Postgres server, or socket directory
    cp_min: 1 # Minimum number of database connections to keep open
    cp_max: 20 # Maximum number of database connections to keep open

# Redis Configuration
redis:
  enabled: true # Required for workers to operate correctly
  path: "/sockets/synapse_redis.sock" # Path to Redis listening socket

# Network Configuration
listeners:
  - path: "/sockets/synapse_replication_main.sock" # Path to Unix socket
    type: http # Type of listener, almost always http
    resources:
      - names: [replication] # Replication allows workers to communicate with the main thread
        compress: false # Whether to compress responses
  - path: "/sockets/synapse_inbound_main.sock" # Path to Unix socket
    type: http # Type of listener, almost always http
    x_forwarded: true # Use the 'X-Forwarded-For' header to recognise the client IP address
    resources:
      - names: [client, federation] # Client API and federation between homeservers
        compress: false # Whether to compress responses
  - type: metrics # Used for Prometheus metrics later
    port: 10101 # Easy port to remember later?

# Workers will eventually go here
instance_map:
  main: # The main process should always be here
    path: "/sockets/synapse_replication_main.sock"

# Trusted Key Servers
trusted_key_servers: # Servers to check for server keys when another server's keys are unknown
  - server_name: "beeper.com"
  - server_name: "matrix.org"
  - server_name: "t2bot.io"
suppress_key_server_warning: true # Suppress warning that matrix.org is in above list

# Federation Configuration
allow_public_rooms_over_federation: false # Allow other servers to read your public room directory
federation: # Back off retrying dead servers as often
  destination_min_retry_interval: 1m
  destination_retry_multiplier: 5
  destination_max_retry_interval: 365d
federation_ip_range_blacklist: # IP address ranges to forbid for federation
  - '10.0.0.0/8'
  - '100.64.0.0/10'
  - '127.0.0.0/8'
  - '169.254.0.0/16'
  - '172.16.0.0/12'
  - '192.168.0.0/16'
  - '::1/128'
  - 'fc00::/7'
  - 'fe80::/64'

# Cache Configuration
event_cache_size: 30K
caches:
  global_factor: 1
  expire_caches: true
  cache_entry_ttl: 1080m
  sync_response_cache_duration: 2m
  per_cache_factors:
    get_current_hosts_in_room: 3
    get_local_users_in_room: 3
    get_partial_current_state_ids: 0.5
    _get_presence_for_user: 3
    get_rooms_for_user: 3
    _get_server_keys_json: 3
    stateGroupCache: 0.1
    stateGroupMembersCache: 0.2
  cache_autotuning:
    max_cache_memory_usage: 896M
    target_cache_memory_usage: 512M
    min_cache_ttl: 30s

# Garbage Collection (Cache Eviction)
gc_thresholds: [550, 10, 10]
gc_min_interval: [1s, 1m, 2m]

# Media Configuration
media_store_path: "/media" # Path where media files will be stored
media_retention:
  local_media_lifetime: 5y # Maximum time to retain local media files
  remote_media_lifetime: 30d # Maximum time to retain remote media files

# User and Room Management
allow_guest_access: false # Whether to allow guest access
auto_join_rooms: # Rooms to auto-join new users to
  - "#welcome-room:mydomain.com"
autocreate_auto_join_rooms: true # Auto-create auto-join rooms if they're missing
presence:
  enabled: true # Enable viewing/sharing of online status and last active time
push:
  include_content: true # Include content of events in push notifications
user_directory:
  enabled: true # Whether to maintain a user directory
  search_all_users: true # Whether to include all users in user directory search results
  prefer_local_users: true # Whether to give local users higher search result ranking

# Data Retention
retention:
  enabled: false # Whether to enable automatic data retention policies
forget_rooms_on_leave: true # Automatically forget rooms when leaving them
forgotten_room_retention_period: 1d # Purge rooms this long after all local users forgot it

# URL Preview Configuration
url_preview_enabled: true # Whether to enable URL previews in messages
url_preview_accept_language: # Language preferences for URL preview content
  - 'en-GB'
  - 'en-US;q=0.9'
  - '*;q=0.8'
url_preview_ip_range_blacklist: # Forbid previews for URLs at IP addresses in these ranges
  - '10.0.0.0/8'
  - '100.64.0.0/10'
  - '127.0.0.0/8'
  - '169.254.0.0/16'
  - '172.16.0.0/12'
  - '192.168.0.0/16'
  - '::1/128'
  - 'fc00::/7'
  - 'fe80::/64'

# SSO Configuration
oidc_providers:
  - idp_id: authentik
    idp_name: "SSO"
    idp_icon: "mxc://mydomain.com/SomeImageURL"
    discover: true
    issuer: "https://auth.fostered.uk/application/o/matrix/"
    client_id: "SuperSecretClientId"
    client_secret: "SuperSecretClientSecret"
    scopes: ["openid", "profile", "email"]
    allow_existing_users: true
    user_mapping_provider:
      config:
        localpart_template: "{{ user.preferred_username }}"
        display_name_template: "{{ user.name|capitalize }}"
        email_template: "{{ user.email }}"

# Email Configuration
email:
  enable_notifs: true # Whether to enable email notifications
  smtp_host: "smtp.mydomain.com" # Hostname of the SMTP server
  smtp_port: 587 # TCP port to connect to SMTP server
  smtp_user: "SuperSecretEmailUser" # Username to connect to SMTP server
  smtp_pass: "SuperSecretEmailPass" # Password to connect to SMTP server
  require_transport_security: True # Require transport security (TLS) for SMTP
  notif_from: "Matrix <noreply@mydomain.com>" # The From address for notification emails
  app_name: Matrix # Name of the app to use in email templates
  notif_for_new_users: True # Enable notifications for new users

# Security and Authentication
form_secret: "SuperSecretValue1" # Secret for preventing CSRF attacks
macaroon_secret_key: "SuperSecretValue2" # Secret for generating macaroons
registration_shared_secret: "SuperSecretValue3" # Shared secret for registration
recaptcha_public_key: "SuperSecretValue4" # Public key for reCAPTCHA
recaptcha_private_key: "SuperSecretValue5" # Private key for reCAPTCHA
worker_replication_secret: "SuperSecretValue6" # Secret for communication between Synapse and workers
```

In this case, I've included typical configuration for [Authentik](https://goauthentik.io/integrations/services/matrix-synapse/)
in case you want to use SSO instead of Synapse's built-in password database - it's perfectly safe to
omit this `oidc_providers:` section if you're not using SSO, but [the official Authentik guide](https://goauthentik.io/integrations/services/matrix-synapse/)
is quite quick and easy if you do wish to use it [after installing Authentik](https://goauthentik.io/docs/installation/docker-compose).

### Cache Optimisation

Most of the example configuration above is fairly standard, however of particular note to
performance tuning is the cache configuration.

The defaults (at time of writing) are below and in the official documentation at [event_cache_size](https://matrix-org.github.io/synapse/latest/usage/configuration/config_documentation.html#event_cache_size)
and [caches](https://matrix-org.github.io/synapse/latest/usage/configuration/config_documentation.html#caches-and-associated-values):

```yaml,filepath=homeserver.yaml
event_cache_size: 10K
caches:
  global_factor: 0.5
  expire_caches: true
  cache_entry_ttl: 30m
  sync_response_cache_duration: 2m
```

In this default case:

- All of the caches (including the `event_cache_size`) are halved (so each worker can only actually
  hold 5,000 events as a maximum)
- Every entry in the cache expires within 30 minutes
- `cache_autotuning` is disabled, so entries leave the cache after 30 minutes or when the server
  needs to cache something and there isn't enough space to store it.

In particular, that last option is a problem, as we have multiple containers, so we don't want every
container seeking to fill its caches to the max then waiting for the expiry time to lose entries
that have only been read once!

I've recommended the following config, which instead:

- Increases the number of events we can cache to lower load on the database
- Enable `cache_autotuning` to remove entries that aren't frequently accessed
- Allow entries to stay in cache longer when they're used frequently
- Modified the limit to expand caches that are frequently accessed by large federated rooms, and
  restricted ones that are less frequently reused

```yaml,filepath=homeserver.yaml
event_cache_size: 30K
caches:
  global_factor: 1
  expire_caches: true
  cache_entry_ttl: 1080m
  sync_response_cache_duration: 2m
  per_cache_factors:
    get_current_hosts_in_room: 3
    get_local_users_in_room: 3
    get_partial_current_state_ids: 0.5
    _get_presence_for_user: 3
    get_rooms_for_user: 3
    _get_server_keys_json: 3
    stateGroupCache: 0.1
    stateGroupMembersCache: 0.2
  cache_autotuning:
    max_cache_memory_usage: 896M
    target_cache_memory_usage: 512M
    min_cache_ttl: 30s
```

Furthermore, as this is designed to be a server with more limited RAM, we've updated the "garbage
collection" thresholds, so Synapse can quickly clean up older cached entries to make sure we're
keeping a healthy amount of cache without running out of memory:

```yaml,filepath=homeserver.yaml
gc_thresholds: [550, 10, 10]
gc_min_interval: [1s, 1m, 2m]
```
