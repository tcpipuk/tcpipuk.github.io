# Tuning PostgreSQL for a Matrix Synapse Homeserver

## 2. PostgreSQL Worker Configuration

PostgreSQL splits work among processes that handle various tasks, from executing queries to performing maintenance operations. Just like in Synapse, these extra threads are called "workers", and the number of them and their configuration can have a huge influence on the performance of your database.

### The Importance of Latency

Speed can be measured in multiple ways: some say "speed" when they mean "bandwidth", but in a realtime application like Synapse that can make hundreds (or thousands) of queries per second, reducing latency (the time it takes for a single piece of data to get from A to B) can make a world of difference.

Synapse's database (particularly the `state_groups_state` table, which typically contains over 90% of the data) is highly sensitive to latency. Each transaction must complete quickly to prevent concurrency issues, where two queries are trying to write the same data and can reach a deadlock. This is where the balance between CPU-bound and IO-bound operations becomes critical:

- **CPU-bound**: The system's performance is primarily limited by CPU power. If a system is CPU-bound, adding more (or faster) cores or optimising the computation can improve performance.
- **I/O-bound**: The system spends more time waiting for I/O operations to complete than actually computing. This could be due to slow disk access, network latency, or other I/O bottlenecks.

For Synapse and PostgreSQL, the goal is to strike a balance: we want to ensure the database isn't CPU-bound, and has enough computational resources to process queries efficiently. However, giving it excessive CPU resources only makes it IO-bound and unable to utilise all of that allocated power.

### Tuning Workers to CPU Cores

More workers don't always mean better performance, in the same way adding infinite cooks to a kitchen doesn't speed up the food.

If there are too many workers, they might end up waiting for locks to clear rather than handling queries, or consuming all of the shared memory on the system. This scenario can lead to the system becoming IO-bound, where the database spends more time waiting for resources than actually processing data, which can degrade performance rather than improve it.

The number of workers in PostgreSQL is closely tied to the number of available CPU cores because each worker process can perform tasks concurrently on a separate core. However, too many workers can lead to resource contention and increased context switching, which can degrade performance.

Here's an example of how you might configure the worker settings in `postgresql.conf`:

```ini
# Set the maximum number of background processes that the system can support
max_worker_processes = 16

# Set the maximum number of workers that the system can use for parallel operations
max_parallel_workers = 16

# Set the maximum number of workers that can be used for a single parallel operation
max_parallel_workers_per_gather = 4

# Set the maximum number of workers that can be used for parallel maintenance operations
max_parallel_maintenance_workers = 4
```

The `max_worker_processes` setting determines the total number of background processes that PostgreSQL can initiate. This includes not only worker processes for parallel queries but also other background processes such as autovacuum workers and replication.

The `max_parallel_workers` setting is the maximum number of workers that can be used for parallel query execution across the entire system. It's recommended to set this equal to the number of CPU cores available to balance the workload without overloading the system.

The `max_parallel_workers_per_gather` setting limits the number of workers that can be used for a single parallel query. Setting this to a quarter of the available cores is a good starting point, as it allows parallel execution without monopolising all resources for a single query, which could starve other queries or processes.

Finally, `max_parallel_maintenance_workers` determines how many workers can be used for maintenance operations such as creating indexes or vacuuming. These operations can be resource-intensive, so it's wise to limit the number of workers to prevent them from impacting the performance of other database activities.

### Checks and Adjustments

#### Enabling Statistics Modules

1. Open your `postgresql.conf` file, search for the `shared_preload_libraries` setting, then add `pg_buffercache,pg_stat_statements` to its value (making sure to comma-separate each entry).

   If it's not present, simply add the following line:

   ```ini
   shared_preload_libraries = 'pg_buffercache,pg_stat_statements'
   ```

2. Restart the PostgreSQL server for the changes to take effect, then run these queries:

   ```sql
   CREATE EXTENSION IF NOT EXISTS pg_buffercache;
   CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
   ```

**Note:** These extensions cause PostgreSQL to use slightly more shared memory, and consume a few percent higher CPU time. There's no harm leaving them running, but as we're tuning for maximum performance, you may wish to disable them again after our investigation with these queries:

```sql
DROP EXTENSION IF EXISTS pg_buffercache;
DROP EXTENSION IF EXISTS pg_stat_statements;
```

#### Monitor CPU Utilisation

Use tools like `top`, `htop`, or `vmstat` to monitor CPU usage, or `docker stats` if using Docker. If the CPU utilisation of Postgres never exceeds 50-60%, consider reducing the number of workers to free up resources for Synapse and other processes.

#### Analysing Query Performance Time

With `pg_stat_statements` enabled, you can now monitor the performance of your SQL statements. Here's a query to help you analyse the database's behaviour:

```sql
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

```sql
SELECT pg_stat_statements_reset();
```

If your server has been running a long time, it's definitely worth running this to ensure you're looking at fresh numbers.

### Balance with Synapse

Remember, Synapse and PostgreSQL are two parts of the same team here, so test at each stage that adjustments made to the database don't adversely impact Synapse's performance.

Browse around your client's UI, scroll through room timelines, and monitor Synapse's logs and performance metrics to ensure everything behaves as expected. We'll cover this in more detail later in the [Testing Methodology](#8-testing-methodology) section.
