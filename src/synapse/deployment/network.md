# Tuning PostgreSQL for a Matrix Synapse Homeserver

## Network Configuration

1. [Network Configuration](#network-configuration)
2. [Unix Sockets](#unix-sockets)
3. [TCP Ports](#tcp-ports)

Choosing the optimal communication method between Synapse and PostgreSQL is essential for
performance. There are two primary methods to consider: Unix sockets and TCP ports. Let's explore
how to configure each one.

## Unix Sockets

Unix sockets provide a high-speed communication channel between processes on the same machine,
bypassing the network stack and reducing latency. This method is ideal when both Synapse and
PostgreSQL are hosted on the same system. Here's how to set it up:

1. Edit the `postgresql.conf` file to specify the directory for the Unix socket:

   ```ini,icon=.devicon-postgresql-plain,filepath=postgresql.conf
   # Set the directory for the Unix socket
   unix_socket_directories = '/var/run/postgresql'
   ```

   Make sure the directory exists and has the correct permissions, then restart the PostgreSQL service.

2. Configure Synapse to use Unix sockets by editing the `homeserver.yaml` file:

   ```yaml,filepath=homeserver.yaml
   database:
   name: psycopg2
   args:
       user: synapse_user
       password: your_password
       database: synapse
       host: /var/run/postgresql
   ```

   After setting the `host` field to the Unix socket directory, restart Synapse for the changes to
	take effect.

   **Note**: Do **not** include the socket filename as Postgres auto-generates the name based on
	the port number. This also means that, if you've changed the default port number in either
	Synapse or PostgreSQL, you must ensure these fields remain after switching to sockets, so both
	applications generate and look for the correct socket name.

## TCP Ports

When Synapse and PostgreSQL are on different hosts or when Unix sockets are not an option, TCP
ports are used for communication. This method is more versatile and allows for distributed setups.
Here's how to configure TCP communication:

1. PostgreSQL listens on TCP port 5432 by default, but you can verify or change this in the
   `postgresql.conf` file:

   ```ini,icon=.devicon-postgresql-plain,filepath=postgresql.conf
   # Listen for TCP connections on the following addresses and ports
   listen_addresses = '*'
   port = 5432
   ```

   Ensure PostgreSQL is configured to accept connections from the Synapse host, and consider
	implementing firewall rules and strong authentication to secure the connection.

2. Point Synapse to the correct TCP port and address in the `homeserver.yaml` file:

   ```yaml,filepath=homeserver.yaml
   database:
   name: psycopg2
   args:
       user: synapse_user
       password: your_password
       database: synapse
       host: postgres.example.com
       port: 5432
   ```

   Replace `postgres.example.com` with the actual hostname or IP address of your PostgreSQL server.
	Restart Synapse to apply the new configuration.
