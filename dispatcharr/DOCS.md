# Home Assistant Add-on: Dispatcharr

Dispatcharr is an open-source IPTV and stream management companion for channels, EPG data, and stream mappings.

This add-on runs the pinned Dispatcharr **0.30.0** all-in-one image (Redis, Celery, nginx, and uWSGI).

## Installation

1. Add this repository to the add-on store (see the repository README).
2. Install **Dispatcharr**.
3. Set your timezone (and optional NAS options).
4. Start the add-on. The first boot can take a minute while Postgres initializes.
5. Open the web UI at `http://homeassistant.local:9191` or use **Open Web UI** on the add-on page.
6. Complete Dispatcharr's first-run setup in the web UI to create the admin account.

## Configuration

| Option | Description | Default |
|--------|-------------|---------|
| `username` | Dispatcharr admin username (passed into the container) | `jeff` |
| `password` | Admin password (masked in the UI). Set this in the add-on Configuration panel; it is not stored in the repository. | _(empty)_ |
| `epg_url` | XMLTV EPG source URL | `https://epg.iptv.cat/epg.xml` |
| `timezone` | IANA timezone, for example `UTC` or `America/New_York` | `UTC` |
| `nas_symlinks` | Redirect recordings, EPG files, and logos onto a media mount | `false` |
| `nas_path` | Media mount path inside the container, for example `/media/nas_data` | _(unset)_ |

Restart the add-on after changing options.

## Access

- `http://homeassistant.local:9191`
- `http://<your-ha-ip>:9191`
- **Open Web UI** on the add-on page

The add-on does not use Ingress. Port 9191 is published on the host.

## Hardware acceleration

`/dev/dri` and Home Assistant video devices are passed through for Intel/AMD VAAPI and QSV transcoding.

On startup, Dispatcharr logs available methods. A "limited DRI device access" warning can be ignored when VAAPI/QSV still show as available.

- **No GPU detected**: confirm host GPU drivers and that `/dev/dri` exists on the host.
- **VAAPI/QSV unavailable**: check that Intel/AMD drivers are loaded on the host.

## Network storage (NAS)

Use Home Assistant's built-in storage UI, not host `fstab` or `docker exec`.

1. Go to **Settings → System → Storage → Add network storage**.
2. Set usage to **Media**.
3. After it connects, the share is available inside this add-on at `/media/<name>`.

To store Dispatcharr recordings, EPG files, and logos on that share:

1. Set `nas_path` to `/media/<name>` (the name you gave the share).
2. Enable `nas_symlinks`.
3. Restart the add-on.

See [docs/MOUNTING_NAS.md](https://github.com/Jster42/dispatcharr-ha-addon/blob/main/docs/MOUNTING_NAS.md) for details.

## Data and backups

Add-on data lives in `/data` (Postgres, settings, and local media). The Supervisor takes a **cold** backup: the add-on is stopped first so the database is consistent.

Files on a NAS mount are **not** part of the add-on backup. Keep a separate copy of that share.

## Troubleshooting

### Web UI not reachable

1. Confirm the add-on is started.
2. Check **Log** on the add-on page. First start often needs 30–60 seconds.
3. Confirm port 9191 is not used by another add-on.
4. Try the Home Assistant IP instead of `homeassistant.local`.

### Add-on will not start

1. Read the add-on logs.
2. Confirm the Supervisor can pull `ghcr.io/dispatcharr/dispatcharr:0.30.0`.
3. If you enabled NAS symlinks, confirm `nas_path` exists (the Storage share is connected).

## Support

- Add-on issues: [dispatcharr-ha-addon](https://github.com/Jster42/dispatcharr-ha-addon/issues)
- Dispatcharr: [Dispatcharr](https://github.com/Dispatcharr/Dispatcharr)
