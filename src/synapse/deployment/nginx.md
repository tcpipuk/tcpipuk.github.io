# Deploying a Synapse Homeserver with Docker

## Nginx Configuration

1. [Nginx Configuration](#nginx-configuration)
2. [Docker Compose](#docker-compose)
3. [Configuration Files](#configuration-files)
   1. [nginx.conf](#nginxconf)
   2. [upstreams.conf](#upstreamsconf)
   3. [maps.conf](#mapsconf)
   4. [locations.conf](#locationsconf)
   5. [proxy.conf](#proxyconf)
   6. [private.conf](#privateconf)

## Docker Compose

Example Docker Compose deployment:

```yaml,icon=.devicon-docker-plain,filepath=docker-compose.yml
  nginx:
    <<: *small-container
    depends_on:
      - synapse
    image: nginx:mainline-alpine-slim
    ports:
      - "8008:8008"
      - "8448:8448"
    tmpfs:
      - /var/cache/nginx/client_temp
    volumes:
      - sockets:/sockets
      - ./nginx/config:/etc/nginx
      - ./nginx/logs:/var/log/nginx/
```

You may already have a reverse proxy in front of your server, but in either case, I recommend a
copy of Nginx deployed alongside Synapse itself so that it can easily use the sockets to
communicate directly with Synapse and its workers, and be restarted whenever Synapse is.

Having Nginx here will provide a single HTTP port to your network to access Synapse on, so outside
your machine it'll behave (almost) exactly the same as a monolithic instance of Synapse, just a lot
faster!

## Configuration Files

I recommend splitting up the config into more manageable files, so next to my `docker-compose.yml`
I have an `nginx` directory with the following file structure:

```bash
docker-compose.yml
nginx
└── config
    ├── locations.conf
    ├── maps.conf
    ├── nginx.conf
    ├── private.conf
    ├── proxy.conf
    └── upstreams.conf
```

My current configuration files are below, with a short summary of what's going on:

### nginx.conf

This is some fairly standard Nginx configuration for a public HTTP service, with one Nginx worker
per CPU core, and larger buffer sizes to accommodate media requests:

```nginx,filepath=nginx.conf
# Worker Performance
worker_processes auto;
worker_rlimit_nofile 8192;
pcre_jit on;

# Events Configuration
events {
  multi_accept off;
  worker_connections 4096;
}

# HTTP Configuration
http {
  # Security Settings
  server_tokens off;

  # Connection Optimisation
  client_body_buffer_size 32m;
  client_header_buffer_size 32k;
  client_max_body_size 1g;
  http2_max_concurrent_streams 128;
  keepalive_timeout 65;
  keepalive_requests 100;
  large_client_header_buffers 4 16k;
  resolver 127.0.0.11 valid=60;
  resolver_timeout 10s;
  sendfile on;
  server_names_hash_bucket_size 128;
  tcp_nodelay on;
  tcp_nopush on;

  # Proxy optimisation
  proxy_buffer_size 128k;
  proxy_buffers 4 256k;
  proxy_busy_buffers_size 256k;

  # Gzip Compression
  gzip on;
  gzip_buffers 16 8k;
  gzip_comp_level 2;
  gzip_disable "MSIE [1-6]\.";
  gzip_min_length 1000;
  gzip_proxied any;
  gzip_types application/javascript application/json application/x-javascript application/xml application/xml+rss image/svg+xml text/css text/javascript text/plain text/xml;
  gzip_vary on;

  # Logging
  log_format balanced '"$proxy_host" "$upstream_addr" >> $http_x_forwarded_for '
                      '"$remote_user [$time_local] "$request" $status $body_bytes_sent '
                      '"$http_referer" "$http_user_agent" $request_time';

  # HTTP-level includes
  include maps.conf;
  include upstreams.conf;

  server {
    # Listen to 8008 for all incoming requests
    listen 8008 default_server backlog=2048 reuseport fastopen=256 deferred so_keepalive=on;
    server_name _;
    charset utf-8;

    # Logging
    access_log /var/log/nginx/access.log balanced buffer=64k flush=1m;
    error_log /var/log/nginx/error.log warn;

    # Server-level includes
    include locations.conf;

    # Redirect any unmatched URIs back to host
    location / {
      return 301 https://$host:8448;
    }
  }
}
```

This specifically just covers HTTP for placing behind another HTTPS proxy if you have one.

If you want this server to handle HTTPS directly in front of the internet, add this:

```nginx,filepath=nginx.conf
http {
  # SSL hardening
  ssl_ciphers EECDH+AESGCM:EDH+AESGCM;
  ssl_prefer_server_ciphers on;
  ssl_protocols TLSv1.2 TLSv1.3;
  ssl_session_cache shared:SSL:10m;
  ssl_session_tickets off;
  ssl_session_timeout 1d;
  ssl_stapling on;
  ssl_stapling_verify on;
  add_header Strict-Transport-Security "max-age=63072000; includeSubdomains";

  # Rest of the config above until the server block, then replace server block with below

  # HTTP redirect
  server {
    listen 8008 default_server backlog=2048 reuseport fastopen=256 deferred so_keepalive=on;
    server_name _;

    # Always redirect to HTTPS
    return 301 https://$host:8448$request_uri;
  }

  # Default HTTPS error
  server {
    listen 8448 ssl default_server backlog=2048 reuseport fastopen=256 deferred so_keepalive=on;
    server_name _;
    charset utf-8;
    http2 on;

    # SSL certificate
    ssl_certificate /path/to/ssl/mydomain.com/fullchain.pem;
    ssl_certificate_key /path/to/ssl/mydomain.com/privkey.pem;    

    # Default security headers
    add_header Referrer-Policy "no-referrer";
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload";
    add_header X-Content-Type-Options "nosniff";
    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-XSS-Protection "1; mode=block";

    # Logging
    access_log /var/log/nginx/access.log balanced buffer=64k flush=1m;
    error_log /var/log/nginx/error.log warn;

    # Server-level includes
    include locations.conf;

    # Return 404 for unmatched location
    return 404;
  }
}
```

### upstreams.conf

This is where we actually list the sockets Nginx will send requests to:

```nginx,filepath=upstreams.conf
# Client non-room requests
upstream synapse_inbound_client_readers {
  # least_conn;
  server unix:/sockets/synapse_inbound_client_reader1.sock max_fails=0;
  keepalive 10;
}

# Client sync workers
upstream synapse_inbound_client_syncs {
  # hash $mxid_localpart consistent;
  server unix:/sockets/synapse_inbound_client_sync1.sock max_fails=0;
  keepalive 10;
}

# Federation non-room requests
upstream synapse_inbound_federation_readers {
  # ip_hash;
  server unix:/sockets/synapse_inbound_federation_reader1.sock max_fails=0;
  keepalive 10;
}

# Media requests
upstream synapse_inbound_media {
  # least_conn;
  server unix:/sockets/synapse_inbound_media1.sock max_fails=0;
  keepalive 10;
}

# Synapse main thread
upstream synapse_inbound_main {
  server unix:/sockets/synapse_inbound_main.sock max_fails=0;
  keepalive 10;
}

# Client/federation room requests
upstream synapse_inbound_room_workers {
  hash $room_name consistent;
  server unix:/sockets/synapse_inbound_rooms1.sock max_fails=0;
  server unix:/sockets/synapse_inbound_rooms2.sock max_fails=0;
  server unix:/sockets/synapse_inbound_rooms3.sock max_fails=0;
  server unix:/sockets/synapse_inbound_rooms4.sock max_fails=0;
  keepalive 10;
}
```

A major change from the default design is my concept of "room workers" that are each responsible
for a fraction of the rooms the server handles.

The theory here is that, by balancing requests using the room ID, each "room worker" only needs to
understand a few of the rooms, and its cache can be very specialised, while massively reducing the
amount of workers we need overall.

I've included the load balancing method you should use for each one, in case you need to add extra
workers - for example, if your server needs to generate lots of thumbnails, or has more than a few
users, you may need an extra media worker.

### maps.conf

These are used to provide "mapping" so Nginx can understand which worker to load balance incoming
requests, no changes should be required:

```nginx,filepath=maps.conf
# Client username from MXID
map $http_authorization $mxid_localpart {
  default                           $http_authorization;
  "~Bearer syt_(?<username>.*?)_.*" $username;
  ""                                $accesstoken_from_urlparam;
}

# Whether to upgrade HTTP connection
map $http_upgrade $connection_upgrade {
  default upgrade;
  '' close;
}

#Extract room name from URI
map $request_uri $room_name {
  default "not_room";
  "~^/_matrix/(client|federation)/.*?(?:%21|!)(?<room>[\s\S]+)(?::|%3A)(?<domain>[A-Za-z0-9.\-]+)" "!$room:$domain";
}
```

### locations.conf

This is the biggest file, and defines which URIs go to which upstream:

```nginx,filepath=locations.conf
### MAIN OVERRIDES ###

# Client: Main overrides
location ~ ^/_matrix/client/(api/v1|r0|v3|unstable)/(account/3pid/|directory/list/room/|pushrules/|rooms/[\s\S]+/(forget|upgrade)|login/sso/redirect/|register) {
  set $proxy_pass http://synapse_inbound_main;
  include proxy.conf;
}

# Client: OpenID Connect SSO
location ~ ^(/_matrix/client/(api/v1|r0|v3|unstable)/login/sso/redirect|/_synapse/client/(pick_username|(new_user_consent|oidc/callback|pick_idp|sso_register)$)) {
  set $proxy_pass http://synapse_inbound_main;
  include proxy.conf;
}

# Federation: Main overrides
location ~ ^/_matrix/federation/v1/openid/userinfo$ {
  set $proxy_pass http://synapse_inbound_main;
  include proxy.conf;
}

### FEDERATION ###

# Federation rooms
location ~ "^/_matrix/(client|federation)/.*?(?:%21|!)[\s\S]+(?:%3A|:)[A-Za-z0-9.\-]+" {
  set $proxy_pass http://synapse_inbound_room_workers;
  include proxy.conf;
}

location ~ ^/_matrix/federation/v[12]/(?:state_ids|get_missing_events)/(?:%21|!)[\s\S]+(?:%3A|:)[A-Za-z0-9.\-]+ {
  set $proxy_pass http://synapse_inbound_room_workers;
  include proxy.conf;
}

# Federation readers
location ~ ^/_matrix/(federation/(v1|v2)|key/v2)/ {
  set $proxy_pass http://synapse_inbound_federation_readers;
  include proxy.conf;
}

### CLIENTS ###

# Stream: account_data
location ~ ^/_matrix/client/(api/v1|r0|v3|unstable)/[\s\S]+(/tags|/account_data) {
  set $proxy_pass http://synapse_inbound_client_syncs;
  include proxy.conf;
}

# Stream: presence
location ~ ^/_matrix/client/(api/v1|r0|v3|unstable)/presence/ {
  set $proxy_pass http://synapse_inbound_client_syncs;
  include proxy.conf;
}

# Stream: receipts
location ~ ^/_matrix/client/(api/v1|r0|v3|unstable)/rooms/[\s\S]+/(receipt|read_markers) {
  set $proxy_pass http://synapse_inbound_client_syncs;
  include proxy.conf;
}

# Stream: to_device
location ~ ^/_matrix/client/(api/v1|r0|v3|unstable)/sendToDevice/ {
  set $proxy_pass http://synapse_inbound_client_syncs;
  include proxy.conf;
}

# Stream: typing
location ~ ^/_matrix/client/(api/v1|r0|v3|unstable)/rooms/[\s\S]+/typing {
  set $proxy_pass http://synapse_inbound_client_syncs;
  include proxy.conf;
}

# Note: The following client blocks must come *after* the stream blocks above
otherwise some stream requests would be incorrectly routed

# Client: User directory
location ~ ^/_matrix/client/(api/v1|r0|v3|unstable)/user_directory/search {
  set $proxy_pass http://synapse_inbound_client_syncs;
  include proxy.conf;
}

# Client: Rooms
location ~ ^/_matrix/client/.*?![\s\S]+:[A-Za-z0-9.\-]+ {
  set $proxy_pass http://synapse_inbound_room_workers;
  include proxy.conf;
}

# Client: Sync
location ~ ^/_matrix/client/((api/)?[^/]+)/(sync|events|initialSync|rooms/[\s\S]+/initialSync)$ {
  set $proxy_pass http://synapse_inbound_client_syncs;
  include proxy.conf;
}

# Client: Reader
location ~ ^/_matrix/client/(api/v1|r0|v3|unstable)/(room_keys/|keys/(query|changes|claim|upload/|room_keys/)|login|register(/available|/m.login.registration_token/validity|)|password_policy|profile|rooms/[\s\S]+/(joined_members|context/[\s\S]+|members|state|hierarchy|relations/|event/|aliases|timestamp_to_event|redact|send|state/|(join|invite|leave|ban|unban|kick))|createRoom|publicRooms|account/(3pid|whoami|devices)|versions|voip/turnServer|joined_rooms|search|user/[\s\S]+/filter(/|$)|directory/room/[\s\S]+|capabilities) {
  set $proxy_pass http://synapse_inbound_main;
  include proxy.conf;
}

# Media
location ~* ^/_matrix/((client|federation)/[^/]+/)media/ {
  set $proxy_pass http://synapse_inbound_media;
  include proxy.conf;
}

# Matrix default
location /_matrix/ {
  set $proxy_pass http://synapse_inbound_main;
  include proxy.conf;
}

# Media admin
location ~ ^/_synapse/admin/v1/(purge_)?(media(_cache)?|room|user|quarantine_media|users)/[\s\S]+|media$ {
  include private.conf;
  set $proxy_pass http://synapse_inbound_media;
  include proxy.conf;
}

# Matrix admin API
location /_synapse/ {
  include private.conf;
  set $proxy_pass http://synapse_inbound_main;
  include proxy.conf;
}
```

It starts by forcing some requests to go directly to the main thread, as workers aren't ready to
handle them yet, and then for each type of request (federation/client) we send specialised requests
to specialised workers, otherwise send any request with a room ID to the "room workers" and
whatever's left goes to our dedicated federation/client reader.

You may also notice that the special "stream" endpoints all go to the
`synapse_inbound_client_syncs` group - if you have multiple sync workers, you'll need to split this
out to a separate worker for stream writing, but for a small number of clients (e.g. a home
install) it's best for performance to keep the caches with your sync workers to maximise caching
and minimise queries to your database.

### proxy.conf

You may have noticed we used "proxy.conf" many times above. We do this to quickly define standard
proxy config, which could easily be overriden per location block if needed later:

```nginx,filepath=proxy.conf
proxy_connect_timeout 2s;
proxy_buffering off;
proxy_http_version 1.1;
proxy_read_timeout 3600s;
proxy_redirect off;
proxy_send_timeout 120s;
proxy_socket_keepalive on;
proxy_ssl_verify off;

proxy_set_header Accept-Encoding "";
proxy_set_header Host $host;
proxy_set_header Connection $connection_upgrade;
proxy_set_header Upgrade $http_upgrade;
```

### private.conf

Lastly, let's approve specific ranges for private access to the admin API. You'll want to define
ranges that can access it, which may include your home/work IP, or private ranges if you're hosting
at home.

Here, I've specified the standard [RFC1918](https://en.wikipedia.org/wiki/Private_network) private
ranges:

```nginx,filepath=private.conf
# Access list for non-public access
allow 10.0.0.0/8;
allow 172.16.0.0/12;
allow 192.168.0.0/16;
deny all;
satisfy all;
```
