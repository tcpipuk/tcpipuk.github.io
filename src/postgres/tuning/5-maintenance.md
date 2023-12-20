# Tuning PostgreSQL for a Matrix Synapse Homeserver

## 5. Maintenance

Regular maintenance of your PostgreSQL database is important and, when configured correctly, PostgreSQL can take care of most of these duties itself.

### Vacuuming

When PostgreSQL deletes data, it doesn't immediately remove it from disk, but rather marks it for removal later. This cleanup task is called "vacuuming", where the old data is removed and the database compacted to improve efficiency and leave less to search in future operations.

### Autovacuum

Autovacuum is PostgreSQL's automated janitor, regularly tidying up to save you doing it manually later. It's a helpful feature that can save you time and effort, but as with most PostgreSQL configuration, the defaults are a rough guess at what the majority of applications might benefit from, and can benefit from tuning to work efficiently with a write-heavy application like Synapse.

Here are the defaults:

```ini,icon=.devicon-postgresql-plain,filepath=postgresql.conf
autovacuum_analyze_scale_factor = 0.1
autovacuum_vacuum_scale_factor = 0.2
autovacuum_vacuum_cost_limit = -1 # uses value of vacuum_cost_limit
vacuum_cost_limit = 200
```

- `autovacuum_analyze_scale_factor`: How often an `ANALYZE`` operation is triggered, measured as a fraction of the table size, so 0.1 should trigger when at least 10% of the table has changed. Analysing the data keeps the statistics more up-to-date, which helps PostgreSQL's query planning.
- `autovacuum_vacuum_scale_factor`: How often a vacuum operation is triggered, 0.2 would mean it runs when 20% of the table can be freed. A lower value means that vacuum will run more frequently, reclaiming space more aggressively.
- `autovacuum_vacuum_cost_limit`: This sets a limit on how much vacuuming work can be done each run. Increasing this value allows the vacuum process to achieve more each cycle, trading extra disk I/O for faster progress.
- `vacuum_cost_limit`: This is the global setting for all vacuum operations, including manual ones. You can adjust the two cost limits separately to have manual and autovacuum operations behave differently.

Here is an example that would run operations more frequently:

```ini,icon=.devicon-postgresql-plain,filepath=postgresql.conf
autovacuum_analyze_scale_factor = 0.05
autovacuum_vacuum_scale_factor = 0.02
autovacuum_vacuum_cost_limit = 400
vacuum_cost_limit = 300
```

This example causes more frequent disk I/O, which could affect performance if your caching and working memory aren't optimal. However, in my experience, running the operations more frequently helps to reduces the amount of work required each time, which in turn can help to make the user experience more consistent too.
