# Tuning PostgreSQL for a Matrix Synapse Homeserver

## 8. Testing Methodology

1. [Monitor Database Connections](#monitor-database-connections)
2. [Adjust Synapse Connection Limits](#adjust-synapse-connection-limits)
3. [Analysing Query Performance](#analysing-query-performance)
	1. [Slowest Queries](#slowest-queries)
	2. [Slowest Queries by Type](#slowest-queries-by-type)
4. [Continuous Monitoring and Iterative Tuning](#continuous-monitoring-and-iterative-tuning)

### Monitor Database Connections

You can use this query to see the number of active and idle connections open to each database:

```sql,icon=.devicon-postgresql-plain,filepath=psql
SELECT datname AS database,
       state AS connection_state,
       count(*) AS connections
FROM pg_stat_activity
WHERE datname IS NOT NULL
GROUP BY state, datname
ORDER BY datname;

 datname | state  | count
---------+--------+-------
 synapse | idle   |    77
 synapse | active |    10
(2 rows)
```

There's no harm in setting `max_connections = 500` in your postgresql.conf, however you may wish to
control the amount of connections Synapse is making if it's hardly using them.

### Adjust Synapse Connection Limits

By default, Synapse is tuned for a single process where all database communication is done by a
single worker. When creating multiple (or dozens!) of workers to spread the load, each worker needs
significantly fewer database connections to complete its task.

In Synapse, you can configure the `cp_min` and `cp_max` values for this:

```yaml,filepath=homeserver.yaml
database:
  name: psycopg2
  args:
...
    cp_min: 1
    cp_max: 6
```

Synapse uses a network library called Twisted, which appears to open `cp_max` connections and never
close them, so there's no harm in setting `cp_min = 1`.

On a monolithic (without workers) Synapse server you could easily set `cp_max = 20` to cover the
many duties it needs to perform. However, with many workers, you can set `cp_max = 6` or lower as
each worker has fewer specialised tasks.

After any changes, restart Synapse and ensure it's behaving correctly, and that there aren't any
logs showing database errors or advising that connections are prematurely closed - it's far easier
to revert a small change now than to troubleshoot the source of a problem later after other changes
have been made.

### Analysing Query Performance

The `pg_stat_statements` extension is a powerful tool for analysing query performance. There are
many different ways to view the data, but below are a couple of examples to try:

#### Slowest Queries

This will give you the top 5 slowest queries, how many times they've been called, the total
execution time, and average execution time:

```sql,icon=.devicon-postgresql-plain,filepath=psql
SELECT LEFT(query, 80) AS short_query,
       calls,
       ROUND(mean_exec_time) AS average_ms,
       ROUND(total_exec_time) AS total_ms
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 5;
```

#### Slowest Queries by Type

If you want to analyse a specific query pattern for slowness, you can filter by the query text:

```sql,icon=.devicon-postgresql-plain,filepath=psql
SELECT LEFT(query, 80) AS short_query,
       ROUND(mean_exec_time) AS average_ms,
       calls,
       ROUND(total_exec_time) AS total_ms
FROM pg_stat_statements
WHERE query LIKE '%INSERT INTO events%'
ORDER BY mean_exec_time DESC
LIMIT 5;
```

This will help you identify places to optimise, for example in this example we're looking at events
being inserted into the database, but could just as easily look at large `SELECT` statements
indexing lots of data.

### Continuous Monitoring and Iterative Tuning

Tuning a PostgreSQL database for Synapse is an iterative process. Monitor the connections, query
performance, and other vital statistics, then adjust the configuration as needed and observe the
impact. Document the changes and the reasons for them, as this could be invaluable for future tuning
or troubleshooting.

Likewise, if you record user statistics or Synapse metrics, it can be really valuable to record some
details when unusual events occur. What happened on the day the server had twice as many active
users as usual? How do Synapse and PostgreSQL react when waves of federation traffic arrive from a
larger server? These events can help you understand where the server has its bad days and allow you
to prepare so you can avoid a panic if the worst should happen.
