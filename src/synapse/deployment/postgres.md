# Deploying a Synapse Homeserver with Docker

## PostgreSQL Configuration

Before we can modify the PostgreSQL config, we need to let the container generate it, so for now (whether you're deploying a single database or a replica too) just start the primary database like this:

```bash
docker compose up db
```

You should see the image be downloaded, then a few seconds later it should have started, with a few logs to say it's created the database and started listening, e.g.

```sql,icon=.devicon-postgresql-plain
PostgreSQL init process complete; ready for start up.

2023-12-20 22:58:57.675 UTC [1] LOG:  starting PostgreSQL 16.1 on x86_64-pc-linux-musl, compiled by gcc (Alpine 13.2.1_git20231014) 13.2.1 20231014, 64-bit
2023-12-20 22:58:57.675 UTC [1] LOG:  listening on IPv4 address "0.0.0.0", port 5432
2023-12-20 22:58:57.675 UTC [1] LOG:  listening on IPv6 address "::", port 5432
2023-12-20 22:58:57.686 UTC [1] LOG:  listening on Unix socket "/var/run/postgresql/.s.PGSQL.5432"
2023-12-20 22:58:57.699 UTC [51] LOG:  database system was shut down at 2023-12-20 22:58:57 UTC
2023-12-20 22:58:57.707 UTC [1] LOG:  database system is ready to accept connections
```

Now you can hit Ctrl+C to close it, and you should find a "psql16" folder now exists with a "postgresql.conf" file inside it. I recommend removing it entirely and replacing with this:

```ini,icon=.devicon-postgresql-plain,filepath=postgresql.conf
# Network
listen_addresses = '0.0.0.0'
max_connections = 500
port = 5432
unix_socket_directories = '/sockets'

# Workers
max_worker_processes = 16
max_parallel_workers = 16
max_parallel_workers_per_gather = 4
max_parallel_maintenance_workers = 4

# Memory
dynamic_shared_memory_type = posix
effective_cache_size = 40GB
effective_io_concurrency = 200
maintenance_work_mem = 1GB
shared_buffers = 4GB
wal_buffers = 128MB
work_mem = 128MB

# Query Planning
enable_partitionwise_join = on
enable_partitionwise_aggregate = on
parallel_setup_cost = 1000
random_page_cost = 1.1

# Performance
commit_delay = 500
commit_siblings = 3
synchronous_commit = off
wal_writer_delay = 500

# Replication
archive_mode = off
checkpoint_completion_target = 0.9
checkpoint_timeout = 15min
hot_standby = off
max_wal_senders = 3
max_wal_size = 4GB
min_wal_size = 1GB
wal_keep_size = 2048
wal_level = replica

# Maintenance
autovacuum_vacuum_cost_limit = 400
autovacuum_analyze_scale_factor = 0.05
autovacuum_vacuum_scale_factor = 0.02
vacuum_cost_limit = 300

# Logging
#log_min_duration_statement = 3000
log_min_messages = warning
log_min_error_statement = warning

# Locale
datestyle = 'iso, mdy'
default_text_search_config = 'pg_catalog.english'
lc_messages = 'en_GB.utf8'
lc_monetary = 'en_GB.utf8'
lc_numeric = 'en_GB.utf8'
lc_time = 'en_GB.utf8'
log_timezone = 'Europe/London'
timezone = 'Europe/London'

# Extensions
#shared_preload_libraries = 'pg_buffercache,pg_stat_statements'
```

This is quite a high spec configuration, designed for a server with over 16 cores and 64GB RAM and using SSD storage, so you may wish to consult [my tuning guide](../../postgres/tuning/2-workers.md) to decide on the best amount of workers and cache for your situation.

If in doubt, it's better to be _more_ conservative, and increase values over time as needed - on a quad-core server with 8GB RAM, these would be reasonable values to start:

```ini,icon=.devicon-postgresql-plain,filepath=postgresql.conf
# Workers
max_worker_processes = 4
max_parallel_workers = 4
max_parallel_workers_per_gather = 2
max_parallel_maintenance_workers = 1

# Memory
dynamic_shared_memory_type = posix
effective_cache_size = 2GB
effective_io_concurrency = 200
maintenance_work_mem = 512MB
shared_buffers = 1GB
wal_buffers = 32MB
work_mem = 32MB
```
