# Extra Tips

1. [Managing Media Files](#managing-media-files)

## Managing Media Files

Synapse provides [configuration options](https://matrix-org.github.io/synapse/latest/usage/configuration/config_documentation.html#media_retention)
to manage media files, such as:

- `media_store_path`: Defines where on the filesystem media files are stored.
- `max_upload_size`: Sets the maximum size for uploaded media files.
- `media_retention`: Configures the duration for which media files are retained before being
  automatically deleted.

Here's an example of how you might configure these in your `homeserver.yaml`:

```yaml,filepath=homeserver.yaml
media_store_path: "/var/lib/synapse/media"
max_upload_size: "10M"
media_retention:
  local_media_lifetime: 3y
  remote_media_lifetime: 30d
```

It's important to note that this takes effect shortly after the next server start, so make sure
you're not removing anything you want to keep. Remote media in particular is less of a concern as
this can be re-retrieved later from other homeservers on demand, but some may wish to keep a local
copy in case that server goes offline in the future.
