# Setting Up a Replica for Backups for PostgreSQL in Docker

## 1. Preparing Docker Compose

Below is an example of my database entry in `docker-compose.yml`:

```yaml,icon=.devicon-docker-plain,filepath=docker-compose.yml
volumes:
  sockets:

services:
  db:
    cpus: 4
    image: postgres:alpine
    environment:
      POSTGRES_DB: synapse
      POSTGRES_USER: synapse
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_INITDB_ARGS: "--encoding=UTF-8 --lc-collate=C --lc-ctype=C"
    mem_limit: 8G
    restart: always
    volumes:
      - sockets:/sockets
      - ./pgsql:/var/lib/postgresql/data
```

As you can see, I'm using a "sockets" volume for Unix socket communication, which as well as
avoiding unnecessary open TCP ports, provides a lower latency connection when containers are on the
same host.

To do the same, just ensure you have this in your `postgresql.conf` to let Postgres know where to
write its sockets:

```ini,icon=.devicon-postgresql-plain,filepath=postgresql.conf
unix_socket_directories = '/sockets'
```

If you're not using sockets (e.g. your replica's on a different host) then you may need to adjust
some of the later steps to replicate via TCP port instead.

I've then added this replica, almost identical except for the standby configuration with lower
resource limits:

```yaml,icon=.devicon-docker-plain,filepath=docker-compose.yml
  db-replica:
    cpus: 2
    depends_on:
      - db
    image: postgres:alpine
    environment:
      POSTGRES_DB: synapse
      POSTGRES_USER: synapse
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_STANDBY_MODE: "on"
      POSTGRES_PRIMARY_CONNINFO: host=/sockets user=synapse password=${POSTGRES_PASSWORD}
    mem_limit: 2G
    restart: always
    volumes:
      - sockets:/sockets
      - ./pgreplica:/var/lib/postgresql/data
```

You can try setting lower limits, I prefer to allow the replica 2 cores to avoid replication
interruptions while the backup runs, as on fast storage this can easily cause one core to run at
100%.
