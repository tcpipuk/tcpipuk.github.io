# Tuning PostgreSQL for a Matrix Synapse Homeserver

## 3. Memory Configuration

Memory plays a pivotal role in the performance of your PostgreSQL database, as does using it efficiently in the right places. Having terrabytes of RAM would undoubtedly speed things up, but the benefit typically drops off quickly after a few gigabytes.

### Shared Buffers

The `shared_buffers` setting determines the amount of memory allocated for PostgreSQL to use for caching data. This cache is critical because it allows frequently accessed data to be served directly from memory, which is much faster than reading from disk.

```conf,lang=ini,icon=.devicon-postgresql-plain,filepath=postgresql.conf
# Set the amount of memory the database server uses for shared memory buffers
shared_buffers = '4GB'
```

As a general guideline, setting `shared_buffers` to approximately 25% of the total system memory is a good starting point on a dedicated database server. However, because PostgreSQL relies on the operating system's cache as well, it's not necessary to allocate all available memory to `shared_buffers`. The optimal size also depends on the nature of your workload and the size of your database.

You can run this query to see the status of your buffers:

```sql,icon=.devicon-postgresql-plain,filepath=psql
WITH block_size AS (
    SELECT setting::integer AS block_size
    FROM pg_settings
    WHERE name = 'block_size'
), buffer_stats AS (
    SELECT
        COUNT(*) * (SELECT block_size FROM block_size) AS total_buffer_bytes,
        SUM(CASE WHEN b.usagecount > 0 THEN (SELECT block_size FROM block_size) ELSE 0 END) AS used_buffer_bytes,
        SUM(CASE WHEN b.isdirty THEN (SELECT block_size FROM block_size) ELSE 0 END) AS unwritten_buffer_bytes
    FROM pg_buffercache b
) SELECT
    pg_size_pretty(total_buffer_bytes) AS total_buffers,
    pg_size_pretty(used_buffer_bytes) AS used_buffers,
    ROUND((used_buffer_bytes::float / NULLIF(total_buffer_bytes, 0)) * 100) AS perc_used_of_total,
    pg_size_pretty(unwritten_buffer_bytes) AS unwritten_buffers,
    ROUND((unwritten_buffer_bytes::float / NULLIF(used_buffer_bytes, 0)) * 100) AS perc_unwritten_of_used
FROM buffer_stats;

 total_buffers | used_buffers | perc_used_of_total | unwritten_buffers | perc_unwritten_of_used
---------------+--------------+--------------------+-------------------+------------------------
 4096 MB       | 1623 MB      |                 40 | 16 MB             |                      1
(1 row)
```

Here I've allocated 4 GiB, but even after an hour of reasonable use, I'm only actually using 1.6 GiB and the unwritten amount is very low, so I could easily lower the buffer if memory was an issue.

As always, this is a rule of thumb. You may choose to allocate more RAM when you have slow storage and want more of the database available in RAM. However, if you're using SSD/NVME storage, this could easily be a waste of RAM that could just as easily be returned to the OS to use as disk cache.

### Shared Memory

Shared memory (specifically the `/dev/shm` area) plays a vital role in PostgreSQL's performance. It behaves like a ramdisk where files are temporarily stored in memory, and in PostgreSQL it's used frequently during sorting and indexing operations, but also in all sorts of other caching and maintenance tasks.

Unfortunately, Docker typically limits this to 64MB, which can severely limit PostgreSQL's performance. If you're using Docker, manually setting `shm_size` in Docker to a similar size as the `shared_buffers` can dramatically improve both query and maintenance performance, as well as reducing disk I/O.

Here's an example of how you might set this in your Docker configuration:

```yaml,icon=.devicon-docker-plain,filepath=docker-compose.yml
services:
  postgres:
    image: postgres:latest
    shm_size: '1gb'
```

There is little value in setting this larger than `shared_buffers`, but the RAM is only consumed while PostgreSQL is using the space, so it's worth setting this to a similar size to `shared_buffers` if you can afford it.

### Effective Cache Size

The `effective_cache_size` parameter helps the PostgreSQL query planner to estimate how much memory is available for disk caching by the operating system and PostgreSQL combined:

```conf,lang=ini,icon=.devicon-postgresql-plain,filepath=postgresql.conf
# Set the planner's assumption about the effective size of the disk cache
effective_cache_size = '8GB'
```

This is not a setting that allocates memory, but rather an help the planner make more informed decisions about query execution. This helps PostgreSQL understand how much memory can be used for caching and can influence decisions such as whether to use an index scan or a sequential scan.

For example, using the `free` command, you might see:

```bash,icon=.devicon-bash-plain,filepath=top
# free -h
               total        used        free      shared  buff/cache   available
Mem:            62Gi        23Gi       3.4Gi       5.5Gi        35Gi        32Gi
Swap:          8.0Gi       265Mi       7.7Gi
```

Or using the `top` command, you might see:

```bash,icon=.devicon-bash-plain,filepath=top
# top -n1 | head -n5
top - 15:20:35 up 14:26,  1 user,  load average: 0.67, 1.92, 2.58
Threads: 5240 total,   1 running, 5239 sleeping,   0 stopped,   0 zombie
%Cpu(s):  1.6 us,  1.5 sy,  0.0 ni, 96.8 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
MiB Mem :  64082.5 total,   3382.0 free,  24445.6 used,  36254.9 buff/cache
MiB Swap:   8192.0 total,   7926.7 free,    265.2 used.  33243.2 avail Mem
```

Here, although only about 3GB is "free", around 36GB is being used by the OS for cache. By setting `effective_cache_size` to a value that reflects this available cache, PostgreSQL can better estimate whether to try accessing the disk, knowing the data is likely to be answered directly from the memory instead.

### Working Memory

The `work_mem` setting controls the amount of memory used for internal sort operations and hash tables instead of writing to temporary disk files:

```conf,lang=ini,icon=.devicon-postgresql-plain,filepath=postgresql.conf
# Set the maximum amount of memory to be used for query workspaces
work_mem = '32MB'
```

Setting this value too low can lead to slow performance due to frequent disk writes, while setting it too high can cause excessive memory consumption if many operations happen concurrently.

Remember that each query operation can potentially use up to `work_mem` memory, so consider the total potential memory usage under peak load when choosing a value.

You can use this query to see how many (and how often) the temporary files are written to disk because the `work_mem` wasn't high enough:

```sql,icon=.devicon-postgresql-plain,filepath=psql
SELECT datname,
       temp_files,
       temp_bytes
FROM pg_stat_database
WHERE datname NOT LIKE 'template%';

 datname  | temp_files | temp_bytes
----------+------------+------------
 synapse  |        292 | 7143424000
(2 rows)
```

Here, temporary files are being created for the Synapse database. Gradually increase `work_mem` by 2-4MB increments, monitoring for 30-60 minutes each time, until temporary files are no longer regularly created.

In practice, values above 32MB often don't make a noticeable difference for Synapse, but you may find higher values (like 64MB or even 128MB) help other applications such as Sliding Sync.

### Maintenance Work Memory

Allocating memory for maintenance operations sets aside room for cleaning and organising your workspace. Properly configured, it helps ensure that routine maintenance doesn't disrupt your database's performance.

In PostgreSQL, when a row is deleted or updated, the old data is not immediately removed from the disk. Instead, it's marked as obsolete, and the VACUUM process is expected to run to clean up this obsolete data, compacting the database, and reclaiming space.

Setting the `maintenance_work_mem` to an optimal value ensures that the VACUUM process has enough memory to perform these tasks efficiently. If you have ample available RAM, you should set this higher (e.g. 512MB-1GB) to minimise maintenance time and table locks.

We'll cover maintenance in more detail later, but properly setting `maintenance_work_mem` now will significantly speed up those tasks later, helping to keep the database compact and efficient.
