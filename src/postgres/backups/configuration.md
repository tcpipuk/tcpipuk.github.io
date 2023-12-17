# Setting Up a Replica for Backups for PostgreSQL in Docker

## 2. Configuration

1. **Primary Postgres Configuration**:

   Now, you'll likely want this at the bottom of your `postgresql.conf` to make sure it's ready to replicate:

   ```ini,icon=.devicon-postgresql-plain,filepath=postgresql.conf
   hot_standby = on
   archive_mode = off
   wal_level = replica
   max_wal_senders = 3
   wal_keep_size = 1024
   ```

   It'll need to be restarted for these changes to take effect, which would be safest done now
   before copying the data:

   ```bash
   docker compose down db && docker compose up db -d
   ```

2. **Preparing Replica Data**:

   Postgres replication involves streaming updates as they're made to the database, so to start
   we'll need to create a duplicate of the current database to use for the replica.

   You can create a copy of your entire database like this, just substitute the container name and
   user as required:

   ```bash
   docker exec -it synapse-db-1 pg_basebackup -h /sockets -U synapse -D /tmp/pgreplica
   ```

   The data is initially written to /tmp/ inside the container as it's safest for permissions. We
   can then move it to /var/lib/postgresql/data/ so we can more easily access it from the host OS:

   ```bash
   docker exec -it synapse-db-1 mv /tmp/pgreplica /var/lib/postgresql/data/
   ```

   You can hopefully now reach the data and move it to a new directory for your replica, updating
   the ownership to match your existing Postgres data directory:

   ```bash
   mv ./pgsql/pgreplica ./
   chown -R 70:1000 ./pgreplica
   ```

3. **Replica Postgres Configuration**:

   Now for the replica's `postgresql.conf`, add this to the bottom to tell it that it's a secondary
   and scale back its resource usage as it won't be actively serving clients:

   ```ini,icon=.devicon-postgresql-plain,filepath=postgresql.conf
   port = 5433
   hot_standby = on
   checkpoint_timeout = 30min
   shared_buffers = 512MB
   effective_cache_size = 1GB
   maintenance_work_mem = 128MB
   work_mem = 4MB
   max_wal_size = 2GB
   max_parallel_workers_per_gather = 1
   max_parallel_workers = 1
   max_parallel_maintenance_workers = 1
   ```

4. **Primary Postgres Replication**

   This will instruct the primary to allow replication:

   ```bash
   # Enable replication for the user
   docker exec -it your_primary_container_name psql -U synapse -c "ALTER USER synapse WITH REPLICATION;"

   # Create a replication slot
   docker exec -it your_primary_container_name psql -U synapse -c "SELECT * FROM pg_create_physical_replication_slot('replica_slot_name');"
   ```
