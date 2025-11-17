# Dispatcharr Home Assistant Add-on

A native Home Assistant add-on for [Dispatcharr](https://github.com/Dispatcharr/Dispatcharr), an open-source IPTV and stream management companion for managing channels, EPG data, and stream mappings.

## Features

- ✅ **Direct Port Access**: Access Dispatcharr via `http://homeassistant.local:9191`
- ✅ **Hardware Acceleration**: Automatic GPU passthrough for Intel/AMD VAAPI/QSV transcoding
- ✅ **Dev Branch Support**: Runs the latest development branch with all-in-one Redis/Celery/Gunicorn stack
- ✅ **Persistent Storage**: All data stored in Home Assistant's `/data` directory
- ✅ **Easy Configuration**: Configure via Home Assistant add-on options (username, EPG URL, timezone)

## Installation

### Option 1: Add Repository (Recommended)

1. In Home Assistant, go to **Settings** → **Add-ons** → **Add-on Store**
2. Click the **⋮** menu (three dots) in the top right → **Repositories**
3. Add this repository URL: `https://github.com/Jster42/dispatcharr-ha-addon`
4. Click **Install** on the Dispatcharr add-on
5. Configure your options (see Configuration below)
6. Click **Start**
7. Access Dispatcharr at `http://homeassistant.local:9191` (or your HA IP address)

### Option 2: Local Installation

1. Copy this repository to your Home Assistant `addons/` directory
2. In Home Assistant: **Settings** → **Add-ons** → **Add-on Store** → **Local add-ons**
3. Install "Dispatcharr"
4. Configure and start as above

## Configuration

Configure the add-on through the Home Assistant add-on options panel:

| Option | Description | Default | Required |
|--------|-------------|---------|----------|
| `username` | Dispatcharr admin username | `jeff` | Yes |
| `password` | Dispatcharr admin password | _(empty)_ | Yes |
| `epg_url` | XMLTV EPG source URL | `https://epg.iptv.cat/epg.xml` | No |
| `timezone` | System timezone | `UTC` | No |

After changing options, restart the add-on for changes to take effect.

## Accessing Dispatcharr

Once the add-on is started, access Dispatcharr at:

- `http://homeassistant.local:9191`
- `http://<your-ha-ip>:9191`

The web interface will be available on port 9191. You can bookmark this URL or add it to your browser favorites.

## Hardware Acceleration

This add-on automatically passes through `/dev/dri` devices to enable hardware-accelerated video transcoding on Intel/AMD GPUs.

### GPU Detection

On startup, Dispatcharr will detect available acceleration methods:

- **VAAPI**: General video transcoding with Intel/AMD GPUs
- **QSV**: Intel-specific optimized transcoding (recommended for Intel GPUs)

### Expected GPU Status

When GPU passthrough is working correctly, you should see in the logs:

```
✅ FFmpeg VAAPI acceleration: AVAILABLE
✅ QSV acceleration: AVAILABLE
✅ Hardware-appropriate acceleration methods available: vaapi qsv
```

### Limited DRI Device Access Warning

You may see a warning like:

```
⚠️ Device access: LIMITED DRI DEVICE ACCESS (0/2)
   VAAPI hardware acceleration may not work properly.
```

**This warning is normal and can be safely ignored** if VAAPI and QSV show as `AVAILABLE`. The limited DRI access detection is conservative, but Dispatcharr will still use hardware acceleration successfully if the detection shows both methods are available.

### Troubleshooting GPU Acceleration

- **No GPU detected**: Ensure your Home Assistant host has GPU drivers installed and `/dev/dri` devices exist
- **VAAPI/QSV unavailable**: Check that Intel/AMD GPU drivers are properly loaded on the host system
- **Acceleration not working**: Verify the GPU is accessible by checking `ls -la /dev/dri` on the Home Assistant host

## Troubleshooting

### Service Not Accessible

If you cannot access Dispatcharr at `http://homeassistant.local:9191`:

1. **Check add-on status**: Ensure the add-on is started (not stopped)
2. **Check add-on logs**: Go to **Settings** → **Add-ons** → **Dispatcharr** → **Log** and look for errors
3. **Verify port is exposed**: The add-on should expose port 9191. Check in **Settings** → **Add-ons** → **Dispatcharr** → **Info** that port 9191 is listed
4. **Check firewall**: Ensure your firewall allows connections to port 9191
5. **Try IP address**: Instead of `homeassistant.local`, try using your Home Assistant's IP address directly

### Service Not Starting

If the add-on fails to start:

1. **Check logs**: Look for error messages in the add-on logs
2. **Check configuration**: Verify all required options are set (username, password)
3. **Check port conflict**: Ensure no other service is using port 9191
4. **Restart Home Assistant**: Sometimes a Home Assistant restart helps resolve issues

### Common Issues

| Issue | Symptom | Solution |
|-------|---------|----------|
| **Port already in use** | Add-on fails to start | Check if another add-on or service is using port 9191 |
| **Service not responding** | Connection refused | Wait 30-60 seconds after starting, services need time to initialize |
| **Wrong port** | Can't connect | Verify you're using port 9191, not 8123 (HA's port) |
| **Firewall blocking** | Connection timeout | Check firewall rules to allow port 9191 |

## Technical Details

### Architecture

- **Base Image**: `ghcr.io/dispatcharr/dispatcharr:dev`
- **Entrypoint**: Uses `/app/docker/entrypoint.sh` which starts Redis, Celery, nginx, and uWSGI automatically
- **Port**: `9191` (exposed directly, not via Ingress)
- **Environment**: Runs in `aio` (all-in-one) mode with embedded Redis and Celery

### Services

The add-on automatically starts these services:

- **Redis**: Broker for Celery tasks
- **Celery**: Background task worker for EPG processing
- **nginx**: Reverse proxy and web server
- **uWSGI**: Django application server

### Data Persistence

All Dispatcharr data is stored in `/data` inside the container, which is mapped to Home Assistant's persistent storage. This includes:

- Channel configurations
- EPG data
- Stream mappings
- User settings
- Database files

## Version Management

This add-on uses automatic version bumping on each commit (via git pre-commit hook). Versions follow semantic versioning with a `-dev` suffix (e.g., `1.0.49-dev`).

To manually bump the version:

```bash
./tools/bump_version.sh
```

## Development

### Local Testing

To test locally before pushing:

```bash
# Pull the dev image to test entrypoint
docker pull ghcr.io/dispatcharr/dispatcharr:dev
docker run --rm -it ghcr.io/dispatcharr/dispatcharr:dev sh

# Discover entrypoint location
./tools/discover_dispatcharr_entrypoint.sh
```

### Updating the Entrypoint

If the Dispatcharr dev branch entrypoint changes:

```bash
./tools/update_addon_run.sh '/new/entrypoint/path.sh'
git add dispatcharr/rootfs/etc/services.d/dispatcharr/run
git commit -m "chore(addon): update entrypoint path"
git push
```

## Support

- **Dispatcharr**: [GitHub Repository](https://github.com/Dispatcharr/Dispatcharr)
- **Issues**: Report add-on specific issues in this repository
- **Documentation**: See [Dispatcharr Documentation](https://github.com/Dispatcharr/Dispatcharr) for Dispatcharr-specific features

## License

This add-on is provided as-is. Dispatcharr itself maintains its own license.
