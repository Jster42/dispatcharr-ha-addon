# Network storage for Dispatcharr

Use Home Assistant's built-in Network Storage. Do not edit `/etc/fstab`, mount from a `shell_command`, or `docker exec` into the add-on.

Official reference: [Home Assistant common tasks — Network storage](https://www.home-assistant.io/common-tasks/os/#network-storage).

## Add a share

1. Go to **Settings → System → Storage**.
2. Select **Add network storage**.
3. Fill in the server, share, and credentials.
4. Set **Usage** to **Media**.
5. Select **Connect**.

Home Assistant creates a directory named after the share under `/media`. This add-on maps `media` read-write, so the same path is available inside Dispatcharr.

Example: a share named `nas_data` is `/media/nas_data` on the host and `/media/nas_data` in the add-on.

## Use the share in Dispatcharr

By default, Dispatcharr keeps recordings, EPG files, and logos in `/data`, which is backed up with the add-on.

To put those directories on the NAS:

1. Open **Settings → Add-ons → Dispatcharr → Configuration**.
2. Set **NAS path** to the media mount, for example `/media/nas_data`.
3. Enable **NAS symlinks**.
4. Save and restart the add-on.

The add-on creates `/media/<name>/dispatcharr/{recordings,epgs,logos}` and points `/data/recordings`, `/data/epgs`, and `/data/logos` at those folders. Existing local data is moved into the share when the destination is empty, or left in a `/data/<name>.backup.<timestamp>` directory if the share already has files.

Files on the NAS are **not** included in Home Assistant add-on backups. Back up that share separately.

## Requirements

- Home Assistant OS 10.2 or newer (Network Storage is built in).
- CIFS/SMB 2.1 or newer, or NFS, as supported by the Storage UI.
- This add-on must be running so it can see `/media`.

## Troubleshooting

**Share not visible in the add-on**

- Confirm the storage entry shows as connected under **Settings → System → Storage**.
- Confirm usage is **Media**, not Backup.
- Restart Dispatcharr after the share is connected.
- Check the add-on log for `nas_path` warnings.

**Permission errors**

The share must be writable by the add-on. Adjust NAS share permissions, or reconnect the storage entry. Dispatcharr also documents `PUID`/`PGID` style ownership for external mounts in its own logs.

**Do not**

- Install the Samba *share* add-on to pull a NAS in. That add-on exports Home Assistant folders outbound.
- Mount from Home Assistant Core `shell_command` automations. Those run in the Core container, not on the host.
- Rely on `/etc/fstab` on Home Assistant OS. Those changes do not persist.
