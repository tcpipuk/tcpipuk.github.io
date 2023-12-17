# Tuning PostgreSQL for a Matrix Synapse Homeserver

## 9. Migrating Major Versions

1. [Preparing for Migration](#preparing-for-migration)
   1. [Creating a Backup with pg\_dumpall](#creating-a-backup-with-pg_dumpall)
2. [Setting Up the New PostgreSQL Version](#setting-up-the-new-postgresql-version)
3. [Restoring Data Manually](#restoring-data-manually)
4. [Completing the Migration](#completing-the-migration)
5. [Reverting Back](#reverting-back)

Newer releases of PostgreSQL don't just come with minor bug fixes, but often major security and
performance improvements. Whenever possible, it's best to keep abreast of these new releases to take
advantage of these benefits.

Minor releases of PostgreSQL (like `16.0` to `16.1`) typically arrive every quarter and are
backwards compatible, so require no extra effort. However, major releases typically come yearly, and
your entire database will need to be migrated from one version to the other to be compatible.

The guide below is written with a Docker user in mind, but if you're using PostgreSQL directly (or
in a VM) you can simply ignore the Docker steps.

### Preparing for Migration

Backups are always recommended, however this process is designed to allow you to revert in minutes
without any loss of data. That said, any work you do on your database is at your own risk and it's
best to ensure you always have multiple copies of all data readily to hand at all times.

Depending on the speed of your storage, this process can take up to an hour, so you may wish to
inform your users about the scheduled downtime.

#### Creating a Backup with pg_dumpall

The most reliable method to migrate the data is to simply export a copy from the old database and
import it into the new one.

`pg_dumpall` is the tool we'll use to do this as it not only includes all databases, but also users
and passwords, so the new one will identically replicate the old one.

1. Make sure your Synapse server is stopped so the database is no longer being written to

2. Log into your current PostgreSQL container:

   ```bash
   docker exec -it your_old_postgres_container bash
   ```

3. Use `pg_dumpall` to create a backup:

   ```bash
   pg_dumpall > /var/lib/postgresql/data/pg_backup.sql
   ```

4. Exit the container and copy the backup file from the old container to a safe location on your
   host:

   ```bash
   docker cp <your_old_postgres_container>:/var/lib/postgresql/data/pg_backup.sql .
   ```

Now you have your entire database in a single `.sql` file, you can stop PostgreSQL and prepare the
new version.

### Setting Up the New PostgreSQL Version

If you're using Docker Compose, you can simply update your `docker-compose.yml` to use the newer
image (e.g. `postgres:16-alpine`) and change the volume mapping to store the data in a new
directory, for example when upgrading from PostgreSQL 15:

```yaml,icon=.devicon-docker-plain,filepath=docker-compose.yml
services:
  db:
    image: postgres:15-alpine
    volumes:
      - ./pgsql15:/var/lib/postgresql/data
```

When moving to PostgreSQL 16 we'd change this to:

```yaml,icon=.devicon-docker-plain,filepath=docker-compose.yml
services:
  db:
    image: postgres:16-alpine
    volumes:
      - ./pgsql16:/var/lib/postgresql/data
      - ./pg_backup.sql:/docker-entrypoint-initdb.d/init.sql
```

Now, when this container starts up, it will automatically load your data before launching the
database for the first time.

**Note:** PostgreSQL will try to create any users you have defined in the environment variables, so
if this interferes with the import, you may need to change the username (e.g. from `synapse` to
`synapsetemp`) then after the import is complete and you're back in Synapse, you can remove this
extra user with `DROP USER synapsetemp;`.

### Restoring Data Manually

If you're not using Docker, or want to load in the data manually, you can simply follow these extra
instructions:

1. If using Docker, copy the backup file to the new container and login:

   ```bash
   docker cp pg_backup.sql your_new_postgres_container:/var/lib/postgresql/data/
   docker exec -it your_new_postgres_container bash
   ```

2. Restore the backup using `psql`:

   ```bash
   psql -U postgres -f /var/lib/postgresql/data/pg_backup.sql
   ```

3. Assuming that went without error, you can now remove the copy you made:

   ```bash
   rm /var/lib/postgresql/data/pg_backup.sql
   ```

### Completing the Migration

PostgreSQL did not include your configuration in the backup, so once the restore is complete, stop
PostgreSQL and copy over your `postgresql.conf` file. When you start it again, it's possible some of
the configuration options may have changed, so watch the logs to confirm it starts without error.

Once this is complete, you should be safe to start Synapse and also confirm it can login to the
database without error.

If you used the automated Docker instructions above, remove the `./pg_backup.sql:/docker-entrypoint-initdb.d/init.sql`
line from the "volumes" section and remove the pg_backup.sql file - nothing should break if you
leave them there, as the `docker-entrypoint-initdb.d` is only read when the Docker image starts with
no databases available, but removing these extra files will save disk space and keep things tidy
ready for the next time.

### Reverting Back

If your new version of PostgreSQL doesn't start up correctly, or Synapse can't connect to it, you're
not stuck!

Take a copy of the logs to help investigation later, then simply stop Synapse and PostgreSQL, and
change back the settings above (e.g. `image:` and `volumes:` if you used the Docker Compose method)
and bring them back up again.

You should now be back up and running on the previous version with plenty of time to investigate
what occurred before the next attempt.
