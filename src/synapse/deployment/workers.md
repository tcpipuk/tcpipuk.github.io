# Deploying a Synapse Homeserver with Docker

## Worker Configuration

1. [Worker Configuration](#worker-configuration)
2. [Introduction](#introduction)
3. [Synapse Configuration](#synapse-configuration)
4. [Worker Config Files](#worker-config-files)
5. [Worker Log Config](#worker-log-config)
6. [Docker Configuration](#docker-configuration)

## Introduction

Due to the way Python handles multiple CPU cores, a design decision was made in Synapse to allow splitting work out between multiple copies with defined roles, rather than trying to shoehorn many processes into a single instance of Synapse.

As a result, we can create multiple workers, say what we want them to do to meet our specific server's needs, and tweak the config to optimise them.

My suggested design is different from the [official documentation](https://matrix-org.github.io/synapse/latest/workers.html), so feel free to study that first, but my recommended model is based on months of testing of various size servers to ensure they can efficiently cope with thousands of rooms and also rooms with tens of thousands of users in them, so I hope you will find it helps.

I've also included an [explanation with a diagram](./README.md#model-explanation) at the bottom of this page to help explain the rationale behind this design, and why it makes the best use of available CPU & RAM.

## Synapse Configuration

In the [initial homeserver.yaml](./synapse.md#homeserver-config) we didn't reference any workers, so will want to add these now.

To begin with, let's tell Synapse the name of workers we want to assign to various roles that can be split out of the main Synapse process:

```yaml,filepath=homeserver.yaml
enable_media_repo: false
federation_sender_instances:
  - sender1
  - sender2
  - sender3
  - sender4
media_instance_running_background_jobs: media1
notify_appservices_from_worker: tasks1
pusher_instances:
  - tasks1
run_background_tasks_on: tasks1
start_pushers: false
stream_writers:
  account_data:
    - client_sync1
  events:
    - tasks1
  presence:
    - client_sync1
  receipts:
    - client_sync1
  to_device:
    - client_sync1
  typing:
    - client_sync1
update_user_directory_from_worker: client_sync1
```

Four federation senders should be plenty for most federating servers that have less than a few hundred users, but a later section will explain how to scale up your server to handle hundreds/thousands of users, should the need arise.

Now we've defined the roles, we also need to add an `instance_map` to tell Synapse how to reach each worker listed in the config entries above:

```yaml,filepath=homeserver.yaml
instance_map:
  main:
    path: "/sockets/synapse_replication_main.sock"
  client_sync1:
    path: "/sockets/synapse_replication_client_sync1.sock"
  media1:
    path: "/sockets/synapse_replication_media1.sock"
  sender1:
    path: "/sockets/synapse_replication_sender1.sock"
  sender2:
    path: "/sockets/synapse_replication_sender2.sock"
  sender3:
    path: "/sockets/synapse_replication_sender3.sock"
  sender4:
    path: "/sockets/synapse_replication_sender4.sock"
  tasks1:
    path: "/sockets/synapse_replication_tasks1.sock"
```

## Worker Config Files

Firstly, I recommend these be stored in a subfolder of your Synapse directory (like "workers") so they're easier to organise.

These are typically very simple, but vary slightly depending on the worker, so I'll explain that below.

```yaml,filepath=workers/client_sync1.yaml
worker_app: "synapse.app.generic_worker" # Always this unless "synapse.app.media_repository"
worker_name: "client_sync1" # Name of worker specified in instance map
worker_log_config: "/data/log.config/client_sync.log.config" # Log config file

worker_listeners:
  # Include for any worker in the instance map above:
  - path: "/sockets/synapse_replication_client_sync1.sock"
    type: http
    resources:
      - names: [replication]
        compress: false
  # Include for any worker that receives requests in Nginx:
  - path: "/sockets/synapse_inbound_client_sync1.sock"
    type: http
    x_forwarded: true # Trust the X-Forwarded-For header from Nginx
    resources:
      - names: [client, federation]
        compress: false
  # Include when using Prometheus or compatible monitoring system:
  - type: metrics
    bind_address: ''
    port: 9000
```

This means, for example, that the Room Workers don't need a replication socket as they are not in the instance map, but do require an inbound socket as Nginx will need to forward events to them:

```yaml,filepath=workers/rooms1.yaml
worker_app: "synapse.app.generic_worker"
worker_name: "rooms1"
worker_log_config: "/data/log.config/rooms.log.config"

worker_listeners:
  - path: "/sockets/synapse_inbound_rooms1.sock"
    type: http
    x_forwarded: true
    resources:
      - names: [client, federation]
        compress: false
  - type: metrics
    port: 10101
```

As above, I recommend having a separate log config for each type of worker to aid any investigation you need to do later, so will explain this in the following section:

## Worker Log Config

These have a [standard format](https://docs.python.org/3/library/logging.config.html), but here I have enabled buffered logging to lower disk I/O, and use a daily log to keep for 3 days before deleting:

```yaml,filepath=log.config/rooms.yaml
version: 1
formatters:
  precise:
    format: '%(asctime)s - %(name)s - %(lineno)d - %(levelname)s - %(request)s - %(message)s'
handlers:
  file:
    class: logging.handlers.TimedRotatingFileHandler
    formatter: precise
    filename: /data/log/rooms.log
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
  synapse.metrics:
    level: WARN
    handlers: [buffer]
  synapse.replication.tcp:
    level: WARN
    handlers: [buffer]
  synapse.util.caches.lrucache:
    level: WARN
    handlers: [buffer]
  twisted:
    level: WARN
    handlers: [buffer]
  synapse:
    level: INFO
    handlers: [buffer]

root:
  level: INFO
  handlers: [buffer]
```

**Note:** While Synapse is running, each line in the log (after the timestamp) starts with a string like `synapse.util.caches.lrucache` so you can control exactly what is logged for each log type by adding some of them to the `loggers` section here. In this example, I've suppressed less informative logs to make the more important ones easier to follow.

## Docker Configuration

Since we defined a "synapse-worker-template" and "synapse-media-template" in the previous [Docker Compose section](./docker.md#yaml-templating), these are very simple to define just below our main Synapse container:

```yaml,icon=.devicon-docker-plain,filepath=docker-compose.yml
  synapse:
    <<: *synapse-template

  client-sync1:
    <<: *synapse-worker-template
    command: run --config-path=/data/homeserver.yaml --config-path=/data/workers/client_sync1.yaml
    healthcheck:
      test: curl -fSs --unix-socket /sockets/synapse_replication_client_sync1.sock http://localhost/health

  federation-reader1:
    <<: *synapse-worker-template
    command: run --config-path=/data/homeserver.yaml --config-path=/data/workers/federation_reader1.yaml
    healthcheck:
      test: curl -fSs --unix-socket /sockets/synapse_inbound_federation_reader1.sock http://localhost/health

  media1:
    <<: *synapse-media-template
    command: run --config-path=/data/homeserver.yaml --config-path=/data/workers/media1.yaml
    healthcheck:
      test: curl -fSs --unix-socket /sockets/synapse_replication_media1.sock http://localhost/health

  rooms1:
    <<: *synapse-worker-template
    command: run --config-path=/data/homeserver.yaml --config-path=/data/workers/rooms1.yaml
    healthcheck:
      test: curl -fSs --unix-socket /sockets/synapse_inbound_rooms1.sock http://localhost/health

  rooms2:
    <<: *synapse-worker-template
    command: run --config-path=/data/homeserver.yaml --config-path=/data/workers/rooms2.yaml
    healthcheck:
      test: curl -fSs --unix-socket /sockets/synapse_inbound_rooms2.sock http://localhost/health

  rooms3:
    <<: *synapse-worker-template
    command: run --config-path=/data/homeserver.yaml --config-path=/data/workers/rooms3.yaml
    healthcheck:
      test: curl -fSs --unix-socket /sockets/synapse_inbound_rooms3.sock http://localhost/health

  rooms4:
    <<: *synapse-worker-template
    command: run --config-path=/data/homeserver.yaml --config-path=/data/workers/rooms4.yaml
    healthcheck:
      test: curl -fSs --unix-socket /sockets/synapse_inbound_rooms4.sock http://localhost/health

  sender1:
    <<: *synapse-worker-template
    command: run --config-path=/data/homeserver.yaml --config-path=/data/workers/sender1.yaml
    healthcheck:
      test: curl -fSs --unix-socket /sockets/synapse_replication_sender1.sock http://localhost/health

  sender2:
    <<: *synapse-worker-template
    command: run --config-path=/data/homeserver.yaml --config-path=/data/workers/sender2.yaml
    healthcheck:
      test: curl -fSs --unix-socket /sockets/synapse_replication_sender2.sock http://localhost/health

  sender3:
    <<: *synapse-worker-template
    command: run --config-path=/data/homeserver.yaml --config-path=/data/workers/sender3.yaml
    healthcheck:
      test: curl -fSs --unix-socket /sockets/synapse_replication_sender3.sock http://localhost/health

  sender4:
    <<: *synapse-worker-template
    command: run --config-path=/data/homeserver.yaml --config-path=/data/workers/sender4.yaml
    healthcheck:
      test: curl -fSs --unix-socket /sockets/synapse_replication_sender4.sock http://localhost/health

  tasks1:
    <<: *synapse-worker-template
    command: run --config-path=/data/homeserver.yaml --config-path=/data/workers/tasks1.yaml
    healthcheck:
      test: curl -fSs --unix-socket /sockets/synapse_replication_tasks1.sock http://localhost/health
```

The "healthcheck" sections just need to match the socket name from each worker's config file - the `/health` endpoint listens on both replication and inbound sockets, so you can use either, depending on what the worker has available. This allows Docker to test whether the container is running, so it can be automatically restarted if there are any issues.

With all of the configuration sections above in place, and the [Nginx upstream configuration](./nginx.md#upstreamsconf) from the previous section, all you should need to do now is run `docker compose down && docker compose up -d` to bring up Synapse with the new configuration and a much higher capacity!
