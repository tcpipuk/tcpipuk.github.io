# Setting Up a Replica for Backups for PostgreSQL in Docker

## 4. Backup Script

I've written the following to take a backup - the files are automatically compressed using gzip before they're written to save space and minimise wear on your storage:

```bash
#!/bin/bash

# Define backup directory, filenames, and the number of backups to keep
BACKUP_DIR="/path/to/backups"
CURRENT_BACKUP="$BACKUP_DIR/backup_$(date +%Y%m%d%H%M).sql.gz"
NUM_BACKUPS_TO_KEEP=6

# Take the backup and compress it using gzip
docker exec synapse-db-replica-1 pg_dump -h /sockets -U synapse -d synapse | gzip > $CURRENT_BACKUP

# Check if the backup was successful
if [ $? -eq 0 ]; then
    echo "Backup successful!"
    # Check if previous backups exist and manage them
    ...
else
    echo "Backup failed!"
    rm $CURRENT_BACKUP
fi
```

To configure, simply set the `BACKUP_DIR` to the location you want your backups to be stored, the `NUM_BACKUPS_TO_KEEP` to the number of previous backups to store before removal, and update the `docker exec` line to match your replica's details.

You could also tailor the script to your specific needs, for example, by adding email notifications to let you know when backups are failing for any reason.

Make sure to mark this script as executable so it can be run:

```bash
chmod +x /path/to/postgres_backup.sh
```

We can then configure a cron job (e.g. in `/etc/cron.d/postgres`) to run it:

```bash
30 */4 * * * root /path/to/postgres_backup.sh 2>&1 | logger -t "postgres-backup"
```

This would run every 4 hours from 12:30am, however you could set a specific list of hours like this:

```bash
30 3,7,11,15,19,23 * * * root /path/to/postgres_backup.sh 2>&1 | logger -t "postgres-backup"
```
