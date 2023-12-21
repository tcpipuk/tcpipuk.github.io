# Tuning PostgreSQL for a Matrix Synapse Homeserver

## 2. Worker Configuration

PostgreSQL splits work among processes that handle various tasks, from executing queries to performing maintenance operations. Just like in Synapse, these extra threads are called "workers", and the number of them and their configuration can have a huge influence on the performance of your database.

### The Importance of Latency

Speed can be measured in multiple ways: some say "speed" when they mean "bandwidth", but in a realtime application like Synapse that can make hundreds (or thousands) of queries per second, reducing latency (the time it takes for a single piece of data to get from A to B) can make a world of difference.

Synapse's database (particularly the `state_groups_state` table, which typically contains over 90% of the data) is highly sensitive to latency. Each transaction must complete quickly to prevent concurrency issues, where two queries are trying to write the same data and can reach a deadlock. This is where the balance between CPU-bound and IO-bound operations becomes critical:

- **CPU-bound**: The system's performance is primarily limited by CPU power. If a system is CPU-bound, adding more (or faster) cores or optimising the computation can improve performance.
- **I/O-bound**: The system spends more time waiting for I/O operations to complete than actually computing. This could be due to slow disk access, network latency, or other I/O bottlenecks.

For Synapse and PostgreSQL, the goal is to strike a balance: we want to ensure the database isn't CPU-bound, and has enough computational resources to process queries efficiently. However, giving it excessive CPU resources only makes it IO-bound and unable to utilise all of that allocated power.

### Tuning Workers to CPU Cores

The number of workers in PostgreSQL is closely tied to the number of available CPU cores because each worker process can perform tasks concurrently on a separate core.

However, too many workers can lead to resource contention and increased context switching, which can degrade performance.

Here's an example of how you might configure the worker settings in `postgresql.conf`:

```ini,icon=.devicon-postgresql-plain,filepath=postgresql.conf
# Maximum number of workers in total, including maintenance and replication
# (typically the number of CPU cores you have)
max_worker_processes = 16

# Maximum number of workers in total that can be used for queries
# (capped by max_worker_processes, so typically the same number)
max_parallel_workers = 16

# Maximum number of workers that can be used for a single query
# (typically a quarter of the total workers)
max_parallel_workers_per_gather = 4

# Maximum number of workers that can be used for maintenance operations
# (typically an eighth to a quarter of the total workers)
max_parallel_maintenance_workers = 4
```

Postgres is generally reliable at choosing how many workers to use, but doesn't necessarily understand the profile of the work you're expecting from it each day, as it doesn't understand how your application (in this case Synapse) is designed.

When all workers are busy, Postgres will queue incoming queries until workers are available, which delays those queries being answered, so you may be tempted to set `max_parallel_workers_per_gather = 1` to ensure more queries are handled immediately. However, if one query requires a lock on a table, then all other workers would need to wait to access that data, so in the Synapse case it's better to use parallelism when possible to speed up complex queries, rather than trying to enable the maximum amount of queries to be running at the same time.

### Checks and Adjustments

#### Enabling Statistics Modules

1. Open your `postgresql.conf` file, search for the `shared_preload_libraries` setting, then add `pg_buffercache,pg_stat_statements` to its value (making sure to comma-separate each entry).

   If it's not present, simply add the following line:

   ```ini,icon=.devicon-postgresql-plain,filepath=postgresql.conf
   shared_preload_libraries = 'pg_buffercache,pg_stat_statements'
   ```

2. Restart the PostgreSQL server for the changes to take effect, then run these queries:

   ```sql,icon=.devicon-postgresql-plain,filepath=psql
   CREATE EXTENSION IF NOT EXISTS pg_buffercache;
   CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
   ```

**Note:** These extensions cause PostgreSQL to use slightly more shared memory, and consume a few percent higher CPU time. There's no harm leaving them running, but as we're tuning for maximum performance, you may wish to disable them again after our investigation with these queries:

```sql,icon=.devicon-postgresql-plain,filepath=psql
DROP EXTENSION IF EXISTS pg_buffercache;
DROP EXTENSION IF EXISTS pg_stat_statements;
```

#### Monitor CPU Utilisation

Use tools like `top`, `htop`, or `vmstat` to monitor CPU usage, or `docker stats` if using Docker. If the CPU utilisation of Postgres never exceeds 50-60%, consider reducing the number of workers to free up resources for Synapse and other processes.

#### Analysing Query Performance Time

With `pg_stat_statements` enabled, you can now monitor the performance of your SQL statements. Here's a query to help you analyse the database's behaviour:

```sql,icon=.devicon-postgresql-plain,filepath=psql
SELECT LEFT(query, 80) AS query,
       calls,
       mean_exec_time AS average_time_ms,
       total_exec_time AS total_time_ms
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 10;
```

This should show the top 10 queries that consumed the most time on average, including the amount of times that query was called, and the total execution time taken. The longest queries are usually not the most common, but by comparing the average time before and after a change at each stage, you can gauge the impact of your optimisations.

#### Resetting Statistics

To reset the statistics collected by `pg_stat_statements`, you can execute the following command:

```sql,icon=.devicon-postgresql-plain,filepath=psql
SELECT pg_stat_statements_reset();
```

If your server has been running a long time, it's definitely worth running this to ensure you're looking at fresh numbers.

### Balance with Synapse

Remember, Synapse and PostgreSQL are two parts of the same team here, so test at each stage that adjustments made to the database don't adversely impact Synapse's performance.

Browse around your client's UI, scroll through room timelines, and monitor Synapse's logs and performance metrics to ensure everything behaves as expected. We'll cover this in more detail later in the [Testing Methodology](8-testing.md) section.
