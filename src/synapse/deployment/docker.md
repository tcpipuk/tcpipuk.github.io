# Deploying a Synapse Homeserver with Docker

## Docker Compose with Templates

1. [Docker Compose with Templates](#docker-compose-with-templates)
2. [Docker Engine](#docker-engine)
3. [Environment Files](#environment-files)
4. [YAML Templating](#yaml-templating)
5. [Unix Sockets](#unix-sockets)
6. [Redis](#redis)
7. [PostgreSQL Database](#postgresql-database)
8. [Synapse](#synapse)

## Docker Engine

If Docker is not already installed, visit [the official guide](https://docs.docker.com/engine/install/#supported-platforms) and select the correct operating system to install Docker Engine.

Once complete, you should now be ready with the latest version of Docker, and can continue the guide.

## Environment Files

Before creating the Docker Compose configuration itself, let's define the environment variables for them:

- Synapse:

  ```ini,filepath=.synapse.env
  SYNAPSE_REPORT_STATS=no
  SYNAPSE_SERVER_NAME=mydomain.com
  UID=1000
  GID=1000
  TZ=Europe/London
  ```

- PostgreSQL:

  ```ini,filepath=.postgres.env
  POSTGRES_DB=synapse
  POSTGRES_USER=synapse
  POSTGRES_PASSWORD=SuperSecretPassword
  POSTGRES_INITDB_ARGS=--encoding=UTF-8 --lc-collate=C --lc-ctype=C
  ```

## YAML Templating

Using [YAML Anchors](https://yaml.org/spec/1.2.2/#3222-anchors-and-aliases) lets you cut down the repeated lines in the config and simplify updating values uniformly.

Docker doesn't try to create anything from blocks starting with `x-` so you can use them to define an `&anchor` that you can then recall later as an `*alias`.

It's not very simple to explain, so take a look at this example, where we establish basic settings for all containers, then upper-limits on CPU and RAM for sizes of container:

```yaml,icon=.devicon-docker-plain,filepath=docker-compose.yml
version: "3"

x-container-template: &container-template
  depends_on:
    - init-sockets
  restart: always

x-small-container: &small-container
  <<: *container-template
  cpus: 1
  mem_limit: 0.5G

x-medium-container: &medium-container
  <<: *container-template
  cpus: 2
  mem_limit: 4G

x-large-container: &large-container
  <<: *container-template
  cpus: 6
  mem_limit: 8G
```

Now we've defined these, we can extend further with more specific templates, first defining what a Synapse container looks like, and variants for the two main types of worker:

```yaml,icon=.devicon-docker-plain,filepath=docker-compose.yml
x-synapse-template: &synapse-template
  <<: *medium-container
  depends_on:
    - init-sockets
    - db
    - redis
  env_file: .synapse.env
  image: matrixdotorg/synapse:latest
  volumes:
    - sockets:/sockets
    - ./logs:/data/logs
    - ./media:/media
    - ./synapse:/data

x-synapse-worker-template: &synapse-worker-template
  <<: *synapse-template
  depends_on:
    - synapse
  environment:
    SYNAPSE_WORKER: synapse.app.generic_worker

x-synapse-media-template: &synapse-media-template
  <<: *synapse-template
  depends_on:
    - synapse
  environment:
    SYNAPSE_WORKER: synapse.app.media_repository

x-postgres-template: &postgres-template
  <<: *large-container
  depends_on:
    - init-sockets
  image: postgres:16-alpine
  env_file: .postgres.env
  shm_size: 2G
```

Now this is done, we're ready to start actually defining resources!

## Unix Sockets

If all of your containers live on the same physical server, you can take advantage of [Unix sockets](https://en.wikipedia.org/wiki/Unix_domain_socket) to bypass the entire network stack when containers need to talk to each other.

This may sound super technical, but in short, it means two different programs can speak directly via the operating system instead of opening a network connection, reducing the time it takes to connect. Synapse is constantly passing messages between workers and replicating data, so this one change makes a very measurable visible difference to client performance for free!

First, let's define a volume to store the sockets. As the sockets are tiny, we can use `tmpfs` so it's stored in RAM to make the connections even faster and minimise disk load:

```yaml,icon=.devicon-docker-plain,filepath=docker-compose.yml
volumes:
  sockets:
    driver_opts:
      type: tmpfs
      device: tmpfs
```

I then recommend a tiny "init-sockets" container to run before the others to make sure the ownership and permissions are set correctly before the other containers start to try writing to it:

```yaml,icon=.devicon-docker-plain,filepath=docker-compose.yml
services:
  init-sockets:
    command:
      - sh
      - -c
      - |
        chown -R 1000:1000 /sockets &&
        chmod 777 /sockets &&
        echo "Sockets initialised!"
    image: alpine:latest
    restart: no
    volumes:
      - sockets:/sockets
```

## Redis

To use sockets, Redis requires an adjustment to the launch command, so we'll define that here:

```yaml,icon=.devicon-docker-plain,filepath=docker-compose.yml
  redis:
    <<: *small-container
    command: redis-server --unixsocket /sockets/synapse_redis.sock --unixsocketperm 660
    image: redis:alpine
    user: "1000:1000"
    volumes:
      - sockets:/sockets
      - ./redis:/data
```

## PostgreSQL Database

Now we can define our PostgreSQL database:

```yaml,icon=.devicon-docker-plain,filepath=docker-compose.yml
  db:
    <<: *postgres-template
    volumes:
      - sockets:/sockets
      - ./pgsql16:/var/lib/postgresql/data
```

And if you're following [my backups guide](../../postgres/backups/README.md), it's now as easy as this to deploy a replica:

```yaml,icon=.devicon-docker-plain,filepath=docker-compose.yml
  db-replica:
    <<: *postgres-template
    environment:
      POSTGRES_STANDBY_MODE: "on"
      POSTGRES_PRIMARY_CONNINFO: host=/sockets user=synapse password=${SYNAPSE_PASSWORD}
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -h /sockets -p 5433 -U synapse"]
      interval: 5s
      timeout: 5s
      retries: 5
    volumes:
      - sockets:/sockets
      - ./pgrep16:/var/lib/postgresql/data
```

You can change the paths from "pgsql" or "pgrep" if you prefer, just make sure to do it before starting the first time, or you'll need to rename the directory on disk at the same time to avoid any data loss.

## Synapse

With all of our templates above, Synapse itself is this easy:

```yaml,icon=.devicon-docker-plain,filepath=docker-compose.yml
  synapse:
    <<: *synapse-template
```

In the next sections, we just need to set up the config files for each of these applications and then you're ready to go.
