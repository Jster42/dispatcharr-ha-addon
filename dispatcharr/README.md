# Dispatcharr Home Assistant Add-on

A native Home Assistant add-on for [Dispatcharr](https://github.com/Dispatcharr/Dispatcharr), an open-source IPTV and stream management companion for managing channels, EPG data, and stream mappings.

## Features

- ✅ **Ingress Support**: Access Dispatcharr directly from Home Assistant's sidebar
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
6. Click **Start** and then **Open Web UI**

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

## Ingress Troubleshooting

If Ingress is not working (e.g., showing "Home Assistant" page or errors):

### Check Add-on Logs

1. In Home Assistant: **Settings** → **Add-ons** → **Dispatcharr** → **Log**
2. Look for messages like:
   - `Starting Dispatcharr with /entrypoint.aio.sh`
   - `✅ Gunicorn started with PID`
   - `Starting Gunicorn...`

### Verify Service is Running

In the add-on logs, you should see:

```
🚀 Starting Gunicorn...
✅ Gunicorn started with PID <pid>
```

If Gunicorn is not starting, check for errors in the logs.

### Verify Port Configuration

- **Ingress Port**: The add-on is configured to use port `9191` for Ingress
- **Gunicorn Binding**: Should bind to `0.0.0.0:9191` (visible in logs)
- If port conflicts occur, check that no other service is using port 9191

### Common Issues

- **Service not started**: Ensure the add-on shows as "Started" in Home Assistant
- **Port mismatch**: Verify `ingress_port: 9191` in the add-on configuration matches what Gunicorn binds to
- **Service crash loop**: Check logs for errors; common causes include missing dependencies or configuration issues
- **Ingress shows HA page**: Usually means the service isn't listening on the configured port yet, or there's a routing issue

### Manual Port Check (Advanced)

If you have SSH access to Home Assistant, you can verify the service is listening:

```bash
# Check if port 9191 is being used by the add-on
docker exec addon_local_dispatcharr netstat -tlnp | grep 9191
# or
docker exec addon_local_dispatcharr ss -tlnp | grep 9191
```

You should see the service listening on `0.0.0.0:9191`.

## Technical Details

### Architecture

- **Base Image**: `ghcr.io/dispatcharr/dispatcharr:dev`
- **Entrypoint**: Uses `/entrypoint.aio.sh` which starts Redis, Celery, and Gunicorn automatically
- **Port**: `9191` (Ingress, no host port exposure needed)
- **Environment**: Runs in `aio` (all-in-one) mode with embedded Redis and Celery

### Services

The add-on automatically starts these services:

- **Redis**: Broker for Celery tasks
- **Celery**: Background task worker for EPG processing
- **Gunicorn**: Django application server

### Data Persistence

All Dispatcharr data is stored in `/data` inside the container, which is mapped to Home Assistant's persistent storage. This includes:

- Channel configurations
- EPG data
- Stream mappings
- User settings
- Database files

## Version Management

This add-on uses automatic version bumping on each commit (via git pre-commit hook). Versions follow semantic versioning with a `-dev` suffix (e.g., `1.0.42-dev`).

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

