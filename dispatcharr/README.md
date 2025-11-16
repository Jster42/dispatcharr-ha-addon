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

If Ingress is not working (e.g., showing "Home Assistant" page, connection errors, or blank page):

### Step 1: Check Add-on Logs

1. In Home Assistant: **Settings** → **Add-ons** → **Dispatcharr** → **Log**
2. Look for these key messages:
   - `=== Ingress Configuration ===` - Shows port configuration
   - `Starting Dispatcharr with /app/docker/entrypoint.sh` or `/entrypoint.aio.sh`
   - `NGINX_PORT: 9191` or `GUNICORN_PORT: 9191`
   - Any error messages about port binding or service startup

### Step 2: Verify Service is Running and Listening

In the add-on logs, you should see the service starting. The service must bind to `0.0.0.0:9191` (not `127.0.0.1:9191`) for Ingress to work.

**For nginx/uWSGI setup** (using `/app/docker/entrypoint.sh`):
- Look for nginx startup messages
- Should show nginx listening on port 9191

**For Gunicorn setup** (using `/entrypoint.aio.sh`):
- Look for: `Starting Gunicorn...` or `Gunicorn started`
- Should show binding to `0.0.0.0:9191`

### Step 3: Verify Port Binding (Advanced)

If you have SSH access to Home Assistant, verify the service is listening correctly:

```bash
# Find your add-on container name
docker ps | grep dispatcharr

# Check if port 9191 is listening (replace CONTAINER_NAME with actual name)
docker exec CONTAINER_NAME netstat -tlnp | grep 9191
# or
docker exec CONTAINER_NAME ss -tlnp | grep 9191

# You should see something like:
# tcp  0  0  0.0.0.0:9191  0.0.0.0:*  LISTEN  <pid>/nginx
# or
# tcp  0  0  0.0.0.0:9191  0.0.0.0:*  LISTEN  <pid>/gunicorn
```

**Critical**: The service MUST listen on `0.0.0.0:9191`, NOT `127.0.0.1:9191`. If you see `127.0.0.1:9191`, Ingress will not work.

### Step 4: Common Issues and Solutions

| Issue | Symptom | Solution |
|-------|---------|----------|
| **Service not binding to 0.0.0.0** | Ingress shows HA page or connection refused | Check logs - service may be binding to 127.0.0.1. The entrypoint script needs to respect `NGINX_PORT` or `GUNICORN_PORT` env vars |
| **Service not started** | Add-on shows as "Stopped" | Check logs for startup errors. Ensure all required environment variables are set |
| **Port conflict** | Service fails to start | Another process may be using port 9191. Check with `netstat` or `ss` |
| **Wrong entrypoint** | Service starts but wrong port | Check logs for which entrypoint is being used. The run script tries `/app/docker/entrypoint.sh` first |
| **Ingress shows blank/HA page** | Page loads but shows Home Assistant | Service may not be listening yet, or there's a routing issue. Wait 30-60 seconds after startup and refresh |

### Step 5: Restart and Wait

After making changes:
1. **Stop** the add-on
2. **Wait 10 seconds**
3. **Start** the add-on
4. **Wait 30-60 seconds** for the service to fully start
5. **Refresh** the Ingress page (hard refresh: Cmd+Shift+R / Ctrl+Shift+R)

### Step 6: Check Home Assistant Supervisor Logs

If Ingress still doesn't work, check the Home Assistant Supervisor logs:
- **Settings** → **System** → **Logs** → Look for errors related to "ingress" or the add-on name

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

