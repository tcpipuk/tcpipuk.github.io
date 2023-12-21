# Deploying a Synapse Homeserver with Docker

## Nginx Configuration

Example Docker Compose deployment:

```yaml,icon=.devicon-docker-plain,filepath=docker-compose.yml
  nginx:
    <<: *small-container
    depends_on:
      - synapse
    image: nginx:mainline-alpine-slim
    ports:
      - "8008:8008"
    tmpfs:
      - /var/cache/nginx/client_temp
    volumes:
      - sockets:/sockets
      - ./nginx/config:/etc/nginx
      - ./logs:/var/log/nginx/
```

You may already have a reverse proxy in front of your server, but in either case, I recommend a copy of Nginx deployed alongside Synapse itself so that it can easily use the sockets to communicate directly with Synapse and its workers, and be restarted whenever Synapse is.

Having Nginx here will provide a single HTTP port to your network to access Synapse on, so outside your machine it'll behave (almost) exactly the same as a monolithic instance of Synapse, just a lot faster!
