# Using Existing NAS Mount with Dispatcharr

If you already have an NFS mount in Home Assistant (e.g., `nas_data`), here's how to use it with Dispatcharr.

## Mount Point Location

Home Assistant typically mounts network shares under `/media/` or `/mnt/`. 

If you see `nas_data` in Home Assistant's media browser (e.g., `media-source://media_source/local/nas_data`), it's configured as a media source and is likely mounted at one of these locations:
- `/media/nas_data`
- `/mnt/nas_data`
- `/share/nas_data`
- `/config/media/nas_data` (if configured as a local media source)

## Checking Your Mount Location

To find where your `nas_data` mount is located:

```bash
# SSH into Home Assistant
ssh hassio@homeassistant.local

# Check all mounts
mount | grep nas_data

# Or check /etc/fstab
cat /etc/fstab | grep nas_data

# Check common mount locations
ls -la /media/
ls -la /mnt/
ls -la /share/
ls -la /config/media/  # If using Home Assistant media source

# Check Home Assistant media source configuration
cat /config/configuration.yaml | grep -A 10 media_source
# or
cat /config/configuration.yaml | grep nas_data
```

## Using with Dispatcharr

The Dispatcharr addon has `map: - media:rw` configured, which means:

- **If your mount is at `/media/nas_data`**: It will be accessible at `/media/nas_data` inside the Dispatcharr container
- **If your mount is at `/mnt/nas_data`**: You may need to create a symlink or remount it under `/media/`

### Option 1: Mount is Already Under /media/ ✅ (Your Setup)

If your `nas_data` is mounted at `/media/nas_data` (which is your case):

1. **Verify it's accessible on host:**
   ```bash
   # From Home Assistant host
   ls -la /media/nas_data
   ```

2. **In Dispatcharr container, it will automatically be at:**
   ```
   /media/nas_data
   ```
   This works because the addon has `map: - media:rw` which maps `/media` from host to `/media` in container.

3. **Verify from Dispatcharr container:**
   ```bash
   # Find container
   docker ps | grep dispatcharr
   
   # Check access
   docker exec <container_id> ls -la /media/nas_data
   ```

4. **Configure Dispatcharr to use this path** in its settings for:
   - Media storage
   - EPG data
   - Recordings
   - Any other file storage needs

**You're all set!** Since your mount is at `/media/nas_data`, it's already accessible to Dispatcharr at the same path.

### Option 2: Mount is Under /mnt/ or Another Location

If your `nas_data` is mounted elsewhere (e.g., `/mnt/nas_data`), you have two options:

**A. Create a Symlink (Quick Fix):**
```bash
# SSH into Home Assistant
ssh hassio@homeassistant.local

# Create symlink
sudo ln -s /mnt/nas_data /media/nas_data

# Verify
ls -la /media/nas_data
```

**B. Remount Under /media/ (Better):**
```bash
# SSH into Home Assistant
ssh hassio@homeassistant.local

# Create mount point
sudo mkdir -p /media/nas_data

# Remount (get the original mount details first)
# Check current mount: mount | grep nas_data
# Then remount to /media/nas_data with same options
```

## Verifying Access from Dispatcharr

Once the mount is accessible at `/media/nas_data` on the host:

1. **Start the Dispatcharr addon**

2. **Check from inside the container:**
   ```bash
   # Find container
   docker ps | grep dispatcharr
   
   # Check if mount is accessible
   docker exec <container_id> ls -la /media/nas_data
   ```

3. **If accessible, you should see your NAS files listed**

## Configuring Dispatcharr to Use the Mount

In Dispatcharr's web interface:

1. Go to **Settings** → **Storage** (or similar)
2. Set paths to use `/media/nas_data`:
   - Media directory: `/media/nas_data/media`
   - EPG directory: `/media/nas_data/epg`
   - Recordings: `/media/nas_data/recordings`
   - Or whatever structure you prefer

## Troubleshooting

### Mount Not Visible in Container

If `/media/nas_data` is not accessible in the Dispatcharr container:

1. **Verify mount on host:**
   ```bash
   mount | grep nas_data
   ls -la /media/nas_data
   ```

2. **Check addon has media mount:**
   - The addon config has `map: - media:rw`
   - This maps `/media` from host to `/media` in container

3. **Restart the addon** after verifying the mount

### Permission Issues

If you get permission errors:

1. **Check mount permissions:**
   ```bash
   ls -la /media/nas_data
   ```

2. **Check mount options:**
   ```bash
   mount | grep nas_data
   ```
   - Should include `uid=1000,gid=1000` or similar
   - May need `rw` option

3. **Fix NFS mount options:**
   ```bash
   # Remount with proper options
   sudo umount /media/nas_data
   sudo mount -t nfs4 NAS_IP:/share /media/nas_data \
     -o rw,noatime,soft,timeo=30,uid=1000,gid=1000
   ```

## Example: Complete Setup

If your `nas_data` NFS mount is at `/mnt/nas_data`:

```bash
# 1. Create symlink to make it accessible under /media/
ssh hassio@homeassistant.local
sudo ln -s /mnt/nas_data /media/nas_data

# 2. Verify
ls -la /media/nas_data

# 3. Restart Dispatcharr addon

# 4. Verify from container
docker exec <dispatcharr_container> ls -la /media/nas_data

# 5. Configure Dispatcharr to use /media/nas_data in its settings
```

That's it! Your `nas_data` mount will now be accessible to Dispatcharr.
