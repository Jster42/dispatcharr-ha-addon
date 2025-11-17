# Changelog

All notable changes to this add-on will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.60-dev] - 2025-11-16

### Changed
- add reference to NAS mounting guide in main README

## [1.0.59-dev] - 2025-11-16

### Changed
- add comprehensive NAS mounting guide

## [1.0.58-dev] - 2025-11-16

### Changed
- add NAS share mounting instructions

## [1.0.57-dev] - 2025-11-16

### Added
- auto-update CHANGELOG on every commit

## [1.0.56-dev] - 2025-11-16

### Fixed
- rewrite CHANGELOG update with macOS-compatible approach

## [1.0.55-dev] - 2025-11-16

### Fixed
- improve CHANGELOG update logic for macOS compatibility

## [1.0.3-dev] - 2025-11-16

### Changed
- Updated changelog documentation

## [1.0.2-dev] - 2025-11-16

### Fixed
- Made git pre-commit hook executable so version auto-increment works on commits
- Made all tool scripts executable for proper functionality

### Changed
- Updated addon run script and README documentation

## [1.0.1-dev] - 2025-11-16

### Added
- Entrypoint discovery debug logging to identify correct entrypoint path
- Comprehensive Ingress troubleshooting documentation
- GPU acceleration documentation with DRI device access warnings explained

### Fixed
- Entrypoint path priority order (entrypoint.aio.sh > entrypoint.sh > /app/docker/entrypoint.sh)
- Explicit GUNICORN_PORT environment variable for Ingress compatibility

### Changed
- Improved entrypoint selection logic with better error messages

## [1.0.0-dev] - 2025-11-16

### Added
- Initial release of Dispatcharr Home Assistant Add-on
- Ingress support for direct access from HA sidebar
- Hardware acceleration support (Intel/AMD GPU passthrough via /dev/dri)
- Automatic environment configuration (DISPATCHARR_ENV=aio, Redis, Celery, Gunicorn)
- Configuration options: username, password, epg_url, timezone
- Persistent storage via Home Assistant /data directory
- Support for dispatcharr/dispatcharr:dev image
- Comprehensive README with installation, configuration, and troubleshooting guides
- Automatic version bumping via git pre-commit hook
- GPU detection and VAAPI/QSV acceleration support

### Technical Details
- Base image: ghcr.io/dispatcharr/dispatcharr:dev
- Port: 9191 (Ingress)
- Architecture: amd64, aarch64
- Services: Redis, Celery worker, Gunicorn (all-in-one mode)

