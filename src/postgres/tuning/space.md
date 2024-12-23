# Tuning PostgreSQL for a Matrix Synapse Homeserver

## 7. Disk Space

1. [Database Size](#database-size)
	1. [Synapse Compress State Utility](#synapse-compress-state-utility)
2. [Media Size](#media-size)

Efficient disk space management ensures that your server remains responsive and that you're making
the most of your available resources. This is difficult to cover in detail, as the applications and
usage of a Matrix server vary wildly, but I've included some general guidance below:

### Database Size

Over time, your PostgreSQL database will grow as more data is added. It's important to keep an eye
on the size of your tables, especially those that are known to grow rapidly, such as
`state_groups_state` in Synapse.

This query will list your largest tables:

```sql,icon=.devicon-postgresql-plain,filepath=psql
WITH table_sizes AS (
    SELECT table_schema,
           table_name, 
           pg_total_relation_size('"' || table_schema || '"."' || table_name || '"') AS size
    FROM information_schema.tables
    WHERE table_schema NOT IN ('pg_catalog', 'information_schema')
    ORDER BY size DESC
)
SELECT table_schema AS schema,
       table_name AS table,
       pg_size_pretty(size) AS "size"
FROM table_sizes
LIMIT 10;

 schema |            table             |  size
--------+------------------------------+--------
 public | state_groups_state           | 29 GB
 public | event_json                   | 818 MB
...
```

On a Synapse server, you should find `state_groups_state` is by far the largest one, and can see
which rooms are the largest with a query like this:

```sql,icon=.devicon-postgresql-plain,filepath=psql
WITH room_counts AS (
    SELECT room_id,
           COUNT(*),
           COUNT(*) * 1.0 / SUM(COUNT(*)) OVER () AS ratio
    FROM state_groups_state
    GROUP BY room_id
), table_sizes AS (
    SELECT table_schema,
           table_name, 
           pg_total_relation_size('"' || table_schema || '"."' || table_name || '"') AS size
    FROM information_schema.tables
    WHERE table_name = 'state_groups_state'
)
SELECT rc.room_id AS room_id,
       rc.count AS state_entries,
       ROUND(rc.ratio * 100, 2) AS percentage,
       pg_size_pretty(ts.size * rc.ratio) AS estimated_size
FROM room_counts rc, table_sizes ts
ORDER BY rc.count DESC
LIMIT 10;

            room_id             | state_entries | percentage | estimated_size
--------------------------------+---------------+------------+----------------
 !OGEhHVWSdvArJzumhm:matrix.org |     125012687 |      91.75 | 26 GB
 !ehXvUhWNASUkSLvAGP:matrix.org |      10003431 |       7.34 | 2152 MB
...
```

#### Synapse Compress State Utility

For Synapse, the `state_groups_state` table can grow significantly. To help manage this, The Matrix
Foundation has developed a tool called [Synapse Compress State](https://github.com/matrix-org/rust-synapse-compress-state)
that can compress state maps without losing any data.

### Media Size

Media files, such as images and videos and other message attachments, are stored on the filesystem
rather than the database, but are tracked in PostgreSQL. Large media files can consume significant
disk space, and it can be a challenge to narrow down what is using all of the space through Synapse
directly.

With this query you can see how many files of each type were uploaded each month, and the total disk
space that consumes:

```sql,icon=.devicon-postgresql-plain,filepath=psql
WITH media_size AS (
    SELECT EXTRACT(YEAR FROM to_timestamp(created_ts / 1000)) AS year,
        EXTRACT(MONTH FROM to_timestamp(created_ts / 1000)) AS month,
        media_type AS mime_type,
        COUNT(*) AS files,
        SUM(media_length) AS total_bytes
    FROM local_media_repository
    GROUP BY media_type, year, month
    ORDER BY total_bytes DESC
)
SELECT year,
    month,
    mime_type,
    files,
    pg_size_pretty(total_bytes) AS total_size
FROM  media_size
LIMIT 10;

 year | month | mime_type  | files | total_size
------+-------+------------+-------+------------
 2023 |     9 | video/mp4  |   464 | 2004 MB
 2023 |     9 | image/png  |   592 | 1648 MB
 2023 |    10 | video/mp4  |   308 | 1530 MB
 2023 |     8 | image/png  |  2614 | 1316 MB
 ...
```

**Note:** For tips on how to have Synapse automatically reduce the size of your media files, see
[Extra Tips](../../synapse/extra-tips.md) in the [Synapse Deployment Guide](../../synapse/README.md).
