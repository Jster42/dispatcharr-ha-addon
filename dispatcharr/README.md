# Dispatcharr Home Assistant Add-on

This add-on wraps Dispatcharr with Ingress on port 9191.

## Install (Local add-ons)
1. Copy this `dispatcharr` folder into your Home Assistant `addons/` directory (or add this repo URL to Add-on Store).
2. In Home Assistant: Settings → Add-ons → Add-on Store → Repositories → Add your repo.
3. Install "Dispatcharr" from Local add-ons.
4. Configure options (username, epg_url, timezone), Start, then Open Web UI.

## Notes
- If Dispatcharr is not installed in the base image, switch the Dockerfile to use the upstream Dispatcharr image and remove the placeholder.
- Data persists in `/data` inside the add-on container.
- **GPU Acceleration**: Intel/AMD GPU devices (`/dev/dri`) are automatically passed through to enable VAAPI/QSV hardware transcoding. The add-on will detect and use available GPU acceleration automatically.

## Dev image entrypoint discovery (local)
Run these on your dev machine to detect the correct start command for `dispatcharr/dispatcharr:dev`, then update the add-on:

```bash
cd /Users/jeffrey.sterner/Downloads/dispatcharr-ha-addon
chmod +x tools/*.sh
./tools/discover_dispatcharr_entrypoint.sh
# Suppose it prints that /entrypoint.sh works, then do:
./tools/update_addon_run.sh '/entrypoint.sh'
git add dispatcharr/rootfs/etc/services.d/dispatcharr/run
git commit -m "chore(addon): use /entrypoint.sh for dev image"
git push
```

