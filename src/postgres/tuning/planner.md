# Tuning PostgreSQL for a Matrix Synapse Homeserver

## 4. Query Planner Configuration

If tuning a database is like orchestrating a complex symphony, the query planner is the conductor
guiding this intricate performance. More literally, the query planner evaluates the multiple
possible ways a given query could be handled, and attempts to choose the most efficient one.

The planner weighs various factors (such as data size, indexes, and available system resources) to
blend performance and accuracy, and we have the opportunity to tune this behaviour, so I've listed
a few common options below that could help optimise queries.

### Cost-Based Parameters

These parameters help PostgreSQL's query planner estimate the relative cost of different query
execution plans:

```ini,icon=.devicon-postgresql-plain,filepath=postgresql.conf
# Cost of a non-sequentially-fetched disk page
random_page_cost = 1.1

# Cost of a sequentially-fetched disk page
seq_page_cost = 0.7

# Cost of processing each row in a query
cpu_tuple_cost = 0.01

# Cost of processing each index entry during an index scan
cpu_index_tuple_cost = 0.005

# Cost of processing each operator or function executed during a query
cpu_operator_cost = 0.0025

# Cost of setting up parallel workers for a parallel operation
parallel_setup_cost = 1000.0

# Minimum amount of table data for a parallel scan to be considered
min_parallel_table_scan_size = 8MB
```

- **`random_page_cost`** (Default: 4.0)
  This setting represents the cost of reading a page randomly from disk. Lowering this value
  (e.g. to 1.1) can be beneficial on systems with fast I/O, like NVME/SSDs, as it makes the planner
  more likely to choose index scans that involve random disk access. You may want to increase it
  further on systems with slower HDDs that have a high seek time.

- **`seq_page_cost`** (Default: 1.0)
  This is the estimated cost of reading a page sequentially from disk. Reducing this value to 0.7
  would make sequential scans more attractive to the planner, which might be preferable if your
  storage is extremely fast.

- **`cpu_tuple_cost`** (Default: 0.01)
  This parameter estimates the cost of processing each row (tuple) during a query. If you have a
  CPU-optimised environment, you might consider lowering this value to make plans that process more
  rows seem less expensive.

- **`cpu_index_tuple_cost`** (Default: 0.005)
  The cost of processing each index entry during an index scan. Adjusting this value influences the
  planner's preference for index scans over sequential scans. A lower value (e.g. 0.03) might
  encourage the use of indexes, but should be done carefully.

- **`cpu_operator_cost`** (Default: 0.0025)
  This setting estimates the cost of processing each operator or function in a query, so can
  discourage more compute-intensive plans.

- **`parallel_setup_cost`** (Default: 1000.0)
  The cost of initiating parallel worker processes for a query. Decreasing this value (e.g. to 500)
  encourages the planner to use parallel query plans, which can be advantageous if you have many CPU
  cores that are underutilised.

- **`min_parallel_table_scan_size`** (Default: 8MB)
  Defines the minimum size of a table scan before the planner considers parallel execution.
  Increasing this value (e.g. to 16MB) may reduce the use of parallelism for smaller tables,
  focusing parallel resources on larger scans. Decreasing it (e.g. to 4MB) might encourage more
  parallelism, even for smaller tables.

### Partitioning Parameters

At the time of writing, Synapse doesn't use partitioning in tables, so these should have no effect.
However, as they have no negative impact on performance, it's worth enabling them in case
partitioned tables appear in the future.

```ini,icon=.devicon-postgresql-plain,filepath=postgresql.conf
# Allows the planner to consider partitions on joins
enable_partitionwise_join = on

# Allows the planner to consider partitions on aggregation
enable_partitionwise_aggregate = on
```

- **`enable_partitionwise_join`:** (Default: off)
  Controls whether the planner can generate query plans that join partitioned tables in a way that
  considers partitions. Enabling this feature (set to `on`) can lead to more efficient join
  operations for partitioned tables.

- **`enable_partitionwise_aggregate`:** (Default: off)
  Controls whether the planner can generate query plans that perform aggregation in a way that
  considers partitions. Similar to joins, enabling this feature (set to `on`) can make aggregation
  queries more efficient for partitioned tables.
