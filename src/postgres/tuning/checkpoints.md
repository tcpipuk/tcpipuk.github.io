# Tuning PostgreSQL for a Matrix Synapse Homeserver

## 6. Checkpoints and Replication

This section primarily deals with the performance options when committing data to disk.

However, if you want to back up the database regularly without impacting the performance of the live database, consider setting up a dedicated replica - it won't _technically_ speed up PostgreSQL, but significantly decreases the performance impact of dumping the backup to disk, and backups typically complete faster too. You can find my guide on this [here](https://gist.github.com/tcpipuk/f68fb199ea8b1c1bdf48833fde86b418).

### Understanding WAL and Checkpoints

Instead of writing each piece of data to the main database file when it arrives, PostgreSQL uses Write-Ahead Logging (WAL) to protect the main database by logging changes into a file as they occur.

This means that, should a crash or power outage occur, the main database file is less likely to become corrupted, and PostgreSQL can try to recover the WAL and commit it into the database the next time it starts up.

In this process, Checkpoints are the points in time where PostgreSQL guarantees that all past changes have been written into the main database files, so tuning this is important to control disk I/O.

### Checkpoint Configuration

- **`checkpoint_completion_target`**: Sets the target time for completing the checkpoint's writing work. The default is 0.5, but increasing this to 0.9 (90% of the checkpoint interval) helps to spread out the I/O load to avoid large amounts of work hitting the disk at once.
- **`checkpoint_timeout`**: Sets the maximum time between checkpoints. This is 5 minutes by default, so increasing to 15 minutes can also help smooth out spikes in disk I/O.

### WAL Size Configuration

For these values, you can use the query from the [Shared Buffers](3-memory.md#shared-buffers) section to see how much of the `shared_buffers` are consumed by new changes in the checkpoint window.

- **`min_wal_size`**: This sets the minimum size for the WAL. Setting this too low can cause unnecessary disk I/O as Postgres tries to reduce and recreate WAL files, so it's better to set this to a realistic figure. In my example with 785MB of changed data, it would be reasonable to set the `min_wal_size` to 1GB.
- **`max_wal_size`**: This is a soft limit, and Postgres will create as much WAL as needed, but setting this to an ample figure helps to reduce disk I/O when there is a spike in changes over the checkpoint window. I typically set this to double the `shared_buffers` value.

### WAL Level Configuration

- If not using replication, set `wal_level = minimal` to keep the WAL efficient with only the data required to restore after a crash.
- If replicating to another server, set `wal_level = replica` to store the necessary data for replication. If you've configured replication, PostgreSQL will actually refuse to start if this is not set!
