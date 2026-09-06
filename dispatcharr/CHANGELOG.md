# Changelog

All notable changes to this add-on are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.1] - 2026-09-06

### Changed
- Restore original add-on option defaults: username `jeff`, EPG URL `https://epg.iptv.cat/epg.xml`, timezone `UTC`, NAS symlinks off.

## [1.1.0] - 2026-09-06

### Changed
- Pin the container image to Dispatcharr 0.30.0 instead of the floating `dev` tag.
- Start Dispatcharr through `/run.sh` and the upstream entrypoint. The add-on no longer assumes s6-overlay is present in the upstream image.
- Map only `media` (read-write). The Home Assistant `config` directory is no longer mounted.
- Use Docker init, a 180 second start/stop timeout, and cold backups so Postgres is stopped before a backup.
- The password field is optional and masked in the UI.
- Timezone is taken from the add-on option (`TZ` / `DISPATCHARR_TIME_ZONE`), not from an invalid `!secret` environment entry.

### Added
- Store documentation (`DOCS.md`), translations, icon, and logo.
- `webui` so **Open Web UI** works without Ingress.
- Optional `nas_path` for Home Assistant Network Storage mounts.
- `video: true` in addition to `/dev/dri` for GPU devices.

### Fixed
- NAS symlink setup no longer deletes data directories with `rm -rf` if a backup move fails.
- NAS documentation now uses **Settings → System → Storage** instead of Samba share, `fstab`, or `docker exec`.

### Removed
- s6 `cont-init.d` / `services.d` scripts and the `/init` entrypoint override.
- Writing the admin password to `/data/dispatcharr.env`.
- Automatic changelog/version bumping on every commit.

## [1.0.68-dev] - 2026-06-18

Historical development builds through 1.0.68-dev used the Dispatcharr `dev` image, s6-style init scripts, and a host port mapping on 9191. See git history for those snapshots.
