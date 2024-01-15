# Setting Up a Replica for Backups for PostgreSQL in Docker

## 4. Backup Script

I've written the following to take a backup - the files are automatically compressed using gzip before they're written to save space and minimise wear on your storage:

```bash
#!/bin/bash

# Define backup directory, filenames, and the number of backups to keep
BACKUP_DIR="/path/to/backups"
CURRENT_BACKUP_DIR="$BACKUP_DIR/backup_$(date +%Y%m%d%H%M)"
CURRENT_BACKUP_ARCHIVE="$CURRENT_BACKUP_DIR.tar.gz"
NUM_BACKUPS_TO_KEEP=6

# Create a new backup using pg_basebackup
mkdir -p $CURRENT_BACKUP_DIR
docker exec synapse-db-replica-1 pg_basebackup -h /sockets -U synapse -D $CURRENT_BACKUP_DIR -Fp

# Check if the backup was successful
if [ $? -eq 0 ]; then
    echo "Backup successful! Compressing the backup directory..."
    
    # Compress the backup directory
    tar -czf $CURRENT_BACKUP_ARCHIVE -C $CURRENT_BACKUP_DIR .
    rm -rf $CURRENT_BACKUP_DIR

    # Check if previous backups exist
    if [ -n "$(ls $BACKUP_DIR/backup_*.tar.gz 2>/dev/null)" ]; then
        PREVIOUS_BACKUPS=($(ls $BACKUP_DIR/backup_*.tar.gz | sort -r))

        # If there are more backups than the specified number, delete the oldest ones
        if [ ${#PREVIOUS_BACKUPS[@]} -gt $NUM_BACKUPS_TO_KEEP ]; then
            for i in $(seq $(($NUM_BACKUPS_TO_KEEP + 1)) ${#PREVIOUS_BACKUPS[@]}); do
                rm -f ${PREVIOUS_BACKUPS[$i-1]}
            done
        fi
    fi
else
    echo "Backup failed!"
    rm -rf $CURRENT_BACKUP_DIR
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
