# Setting Up a Replica for Backups for PostgreSQL in Docker

## 3. Starting Replication

Once you run `docker compose up db-replica -d` your new replica should now be running.

Running this command confirms that the primary sees the replica and is streaming data to it:

```bash
docker exec -it synapse-db-1 psql -h /sockets -U synapse -d synapse -c "SELECT application_name, state, sync_priority, sync_state, pg_current_wal_lsn() - sent_lsn AS bytes_behind FROM pg_stat_replication;"
```

The output should look something like this:

```bash
 application_name |   state   | sync_priority | sync_state | bytes_behind
------------------+-----------+---------------+------------+--------------
 walreceiver      | streaming |             0 | async      |            0
(1 row)
```

### Replica Logs

When running `docker logs synapse-db-replica-1` (adjusting your replica's name as necessary) we should now see messages distinct from the primary's typical "checkpoint" logs. Here's a concise breakdown using an example log:

```yaml
LOG:  entering standby mode
LOG:  consistent recovery state reached at [WAL location]
LOG:  invalid record length at [WAL location]: wanted [X], got 0
LOG:  started streaming WAL from primary at [WAL location] on timeline [X]
LOG:  restartpoint starting: [reason]
LOG:  restartpoint complete: ...
LOG:  recovery restart point at [WAL location]
```

**Key Points**:

- **Entering Standby Mode**: The replica is ready to receive WAL records.
- **Consistent Recovery State**: The replica is synchronized with the primary's WAL records.
- **Invalid Record Length**: An informational message indicating the end of available WAL records.
- **Started Streaming WAL**: Active replication is in progress.
- **Restart Points**: Periodic checkpoints in the replica for data consistency.
- **Recovery Restart Point**: The point where recovery would begin if the replica restarts.

If you're seeing errors here, double-check the steps above: Postgres will refuse to start if the configuration between the two containers is too different, so if you've skipped steps or done them out of order then it should explain quite verbosely what went wrong here.
