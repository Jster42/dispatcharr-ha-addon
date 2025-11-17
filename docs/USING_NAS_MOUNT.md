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

4. **Use symlinks to redirect Dispatcharr's data directories to NAS:**

   Dispatcharr uses hardcoded paths under `/data` (no storage settings UI). To use your NAS for storage, create symlinks inside the container:

   ```bash
   # Find the Dispatcharr container
   docker ps | grep dispatcharr
   
   # Create directories on NAS (if they don't exist)
   # You can do this from the host or inside the container
   
   # Create symlinks inside the container (run these commands)
   docker exec -it <container_id> sh -c "
     # Backup existing directories (if they have data)
     mv /data/recordings /data/recordings.backup 2>/dev/null || true
     mv /data/epgs /data/epgs.backup 2>/dev/null || true
     mv /data/logos /data/logos.backup 2>/dev/null || true
     
     # Create directories on NAS
     mkdir -p /media/nas_data/dispatcharr/recordings
     mkdir -p /media/nas_data/dispatcharr/epgs
     mkdir -p /media/nas_data/dispatcharr/logos
     
     # Create symlinks
     ln -s /media/nas_data/dispatcharr/recordings /data/recordings
     ln -s /media/nas_data/dispatcharr/epgs /data/epgs
     ln -s /media/nas_data/dispatcharr/logos /data/logos
     
     # Restore data from backup if needed
     cp -r /data/recordings.backup/* /data/recordings/ 2>/dev/null || true
     cp -r /data/epgs.backup/* /data/epgs/ 2>/dev/null || true
     cp -r /data/logos.backup/* /data/logos/ 2>/dev/null || true
   "
   ```

   **Note:** These symlinks will be lost when the container restarts. See "Making Symlinks Persistent" below for a permanent solution.

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

## Making Symlinks Persistent

The addon includes an automatic symlink creation feature that you can enable via the addon options:

1. **Enable automatic symlinks (Recommended):**

   - Go to **Settings** → **Add-ons** → **Dispatcharr** → **Configuration**
   - Add `nas_symlinks: true` to your configuration:
     ```yaml
     username: jeff
     password: ""
     epg_url: https://epg.iptv.cat/epg.xml
     timezone: UTC
     nas_symlinks: true
     ```
   - Click **Save** and restart the addon
   - The symlinks will be automatically created on every startup

2. **Manual symlink creation (if you prefer not to use the option):**

   ```bash
   # Save this as recreate_symlinks.sh on your Home Assistant host
   #!/bin/bash
   CONTAINER=$(docker ps | grep dispatcharr | awk '{print $1}' | head -1)
   if [ -n "$CONTAINER" ]; then
     docker exec $CONTAINER sh -c "
       rm -rf /data/recordings /data/epgs /data/logos
       mkdir -p /media/nas_data/dispatcharr/{recordings,epgs,logos}
       ln -s /media/nas_data/dispatcharr/recordings /data/recordings
       ln -s /media/nas_data/dispatcharr/epgs /data/epgs
       ln -s /media/nas_data/dispatcharr/logos /data/logos
     "
   fi
   ```

   Run this script after each addon restart, or set it up as a cron job or Home Assistant automation.

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

## Example: Complete Setup for /media/nas_data

Since your `nas_data` is already at `/media/nas_data`:

```bash
# 1. Verify mount is accessible
ssh hassio@homeassistant.local
ls -la /media/nas_data

# 2. Start Dispatcharr addon (if not running)

# 3. Find container
CONTAINER=$(docker ps | grep dispatcharr | awk '{print $1}' | head -1)

# 4. Verify NAS is accessible from container
docker exec $CONTAINER ls -la /media/nas_data

# 5. Create directories on NAS and symlinks
docker exec -it $CONTAINER sh -c "
  # Backup existing data (if any)
  [ -d /data/recordings ] && mv /data/recordings /data/recordings.backup || true
  [ -d /data/epgs ] && mv /data/epgs /data/epgs.backup || true
  [ -d /data/logos ] && mv /data/logos /data/logos.backup || true
  
  # Create directories on NAS
  mkdir -p /media/nas_data/dispatcharr/{recordings,epgs,logos}
  
  # Create symlinks
  ln -s /media/nas_data/dispatcharr/recordings /data/recordings
  ln -s /media/nas_data/dispatcharr/epgs /data/epgs
  ln -s /media/nas_data/dispatcharr/logos /data/logos
  
  # Restore data if backed up
  [ -d /data/recordings.backup ] && cp -r /data/recordings.backup/* /data/recordings/ || true
  [ -d /data/epgs.backup ] && cp -r /data/epgs.backup/* /data/epgs/ || true
  [ -d /data/logos.backup ] && cp -r /data/logos.backup/* /data/logos/ || true
"

# 6. Verify symlinks
docker exec $CONTAINER ls -la /data/ | grep -E "(recordings|epgs|logos)"
```

**Note:** Remember to recreate the symlinks after each addon restart, or set up the persistent script mentioned above.
