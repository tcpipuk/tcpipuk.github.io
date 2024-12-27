# SSL Certificates for Matrix Servers

This guide covers obtaining SSL certificates for your Matrix homeserver using Certbot. We'll cover
both DNS validation (recommended) and HTTP validation methods.

1. [DNS Validation](#dns-validation)
2. [HTTP Validation](#http-validation)
3. [Certificate Renewal](#certificate-renewal)
4. [Automatic Reloading](#automatic-reloading)

## DNS Validation

DNS validation is the recommended method as it:

- Allows wildcard certificates (*.server.name)
- Doesn't require exposing ports 80/443 during validation
- Can be automated without temporary web server configuration

Certbot provides plugins for many DNS providers. Here are some common options:

- **Cloudflare**

  ```bash
  # Cloudflare
  apt install python3-certbot-dns-cloudflare
  certbot certonly --dns-cloudflare --dns-cloudflare-credentials ~/.secrets/cloudflare.ini -d server.name -d *.server.name
  ```

- **Digital Ocean**

  ```bash
  # Digital Ocean
  apt install python3-certbot-dns-digitalocean
  certbot certonly --dns-digitalocean --dns-digitalocean-credentials ~/.secrets/digitalocean.ini -d server.name -d *.server.name
  ```

- **OVH**

  ```bash
  # OVH
  apt install python3-certbot-dns-ovh
  certbot certonly --dns-ovh --dns-ovh-credentials ~/.secrets/ovh.ini -d server.name -d *.server.name
  ```

- **Route53**

  ```bash
  # Route53
  apt install python3-certbot-dns-route53
  certbot certonly --dns-route53 -d server.name -d *.server.name
  ```

Each provider requires appropriate credentials, which you can store securely in your profile:

```bash
# Create credentials directory
mkdir -p ~/.secrets

# Create and edit your provider's credentials file
nano ~/.secrets/provider.ini

# Secure the credentials
chmod 600 ~/.secrets/provider.ini
```

## HTTP Validation

If DNS validation isn't an option, you can use HTTP validation. This requires:

- Separate certificates for each domain/subdomain
- Temporary HTTP access during validation
- Web server configuration for validation challenges

1. Stop your reverse proxy temporarily:

   ```bash
   systemctl stop nginx
   ```

2. Generate certificates:

   ```bash
   # Main domain
   certbot certonly --standalone -d server.name

   # Matrix subdomain
   certbot certonly --standalone -d matrix.server.name
   ```

3. Restart your reverse proxy:

   ```bash
   systemctl start nginx
   ```

## Certificate Renewal

Certbot automatically installs a renewal timer, but you can test the renewal process:

```bash
# Test renewal (no changes made)
certbot renew --dry-run

# Force renewal for testing
certbot renew --force-renewal

# Check timer status
systemctl status certbot.timer
```

## Automatic Reloading

Create a renewal hook to reload Nginx when certificates are renewed:

```bash
# Create hooks directory if it doesn't exist
mkdir -p /etc/letsencrypt/renewal-hooks/deploy

# Create reload script
cat > /etc/letsencrypt/renewal-hooks/deploy/nginx-reload << 'EOF'
#!/bin/bash
systemctl reload nginx
EOF

# Make it executable
chmod +x /etc/letsencrypt/renewal-hooks/deploy/nginx-reload
```

Now your certificates will automatically renew and reload Nginx when needed.
