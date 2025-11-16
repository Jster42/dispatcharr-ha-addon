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
