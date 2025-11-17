# Mounting NAS Shares in Home Assistant

This guide explains how to mount network storage (NAS) shares in Home Assistant so they're accessible to addons like Dispatcharr.

## Method 1: Using Samba/CIFS Add-on (Easiest - Recommended)

The Samba/CIFS add-on is the easiest way to mount network shares in Home Assistant.

### Installation

1. Go to **Settings** → **Add-ons** → **Add-on Store**
2. Search for **"Samba share"** or **"CIFS"**
3. Install the add-on (there may be multiple options - choose one that supports mounting)

### Configuration

1. Open the Samba/CIFS add-on configuration
2. Configure your NAS connection:
   - **Server**: Your NAS IP address (e.g., `192.168.1.100`)
   - **Share**: Share name (e.g., `media`, `videos`, `storage`)
   - **Username**: NAS username
   - **Password**: NAS password
   - **Workgroup**: Usually `WORKGROUP` (default)
   - **Mount point**: `/media/nas` or `/media/dispatcharr` (where you want it mounted)

3. **Start** the add-on

4. Verify the mount:
   ```bash
   # SSH into Home Assistant
   ssh hassio@homeassistant.local
   
   # Check if mounted
   ls -la /media/nas
   # or
   ls -la /media/dispatcharr
   ```

## Method 2: Manual Mount via SSH (Advanced)

If you prefer manual control or need NFS support:

### Step 1: Enable SSH in Home Assistant

1. Go to **Settings** → **Add-ons** → **Add-on Store**
2. Install **"Terminal & SSH"** add-on (or "SSH & Web Terminal")
3. Configure and start it

### Step 2: SSH into Home Assistant

```bash
ssh hassio@homeassistant.local
# or
ssh root@homeassistant.local
```

### Step 3: Create Mount Point

```bash
sudo mkdir -p /media/nas
# or for Dispatcharr specifically
sudo mkdir -p /media/dispatcharr
```

### Step 4: Install Required Tools

**For CIFS/Samba:**
```bash
# On Home Assistant OS (HassOS)
# CIFS support is usually already available
# If not, you may need to use an add-on

# On Home Assistant Supervised (Docker)
apk add cifs-utils  # Alpine-based
# or
apt-get install cifs-utils  # Debian-based
```

**For NFS:**
```bash
# On Home Assistant OS
# NFS support is usually already available

# On Home Assistant Supervised
apk add nfs-utils  # Alpine-based
# or
apt-get install nfs-common  # Debian-based
```

### Step 5: Mount the Share

**For Samba/CIFS:**
```bash
sudo mount -t cifs //NAS_IP/share_name /media/nas \
  -o username=your_username,password=your_password,uid=1000,gid=1000,iocharset=utf8
```

**For NFS:**
```bash
sudo mount -t nfs4 NAS_IP:/share_name /media/nas \
  -o rw,noatime,soft,timeo=30
```

Replace:
- `NAS_IP`: Your NAS IP address (e.g., `192.168.1.100`)
- `share_name`: Your share name (e.g., `media`, `videos`)
- `your_username`: Your NAS username
- `your_password`: Your NAS password

### Step 6: Make Mount Persistent

To make the mount survive reboots, add it to `/etc/fstab`:

**For CIFS:**
```bash
sudo nano /etc/fstab
```

Add this line:
```
//NAS_IP/share_name /media/nas cifs username=your_username,password=your_password,uid=1000,gid=1000,iocharset=utf8,file_mode=0777,dir_mode=0777 0 0
```

**For NFS:**
```
NAS_IP:/share_name /media/nas nfs4 rw,noatime,soft,timeo=30 0 0
```

**Note:** On Home Assistant OS, `/etc/fstab` changes may not persist across updates. Consider using an add-on or automation instead.

## Method 3: Using Shell Command + Automation

Create a persistent mount using Home Assistant's shell_command and automation:

### Step 1: Add to configuration.yaml

```yaml
shell_command:
  mount_nas: |
    mkdir -p /media/nas
    mount -t cifs //NAS_IP/share_name /media/nas \
      -o username=your_username,password=your_password,uid=1000,gid=1000,iocharset=utf8
```

### Step 2: Create Automation

```yaml
automation:
  - alias: "Mount NAS Share on Startup"
    trigger:
      - platform: homeassistant
        event: start
    action:
      - service: shell_command.mount_nas
```

### Step 3: Restart Home Assistant

After adding the configuration, restart Home Assistant.

## Method 4: Using Network Storage Add-on

Some Home Assistant installations have dedicated "Network Storage" add-ons:

1. Check **Settings** → **Add-ons** → **Add-on Store**
2. Search for "Network Storage" or "NFS" or "CIFS"
3. Install and configure as per the add-on's instructions

## Verifying the Mount

After mounting, verify it's working:

```bash
# Check if mounted
mount | grep /media/nas

# List contents
ls -la /media/nas

# Check disk space
df -h /media/nas
```

## Troubleshooting

### Mount Fails with "Permission Denied"

- Check NAS share permissions
- Verify username/password
- Try adding `uid=1000,gid=1000` to mount options
- For CIFS, try `file_mode=0777,dir_mode=0777`

### Mount Doesn't Persist After Reboot

- On Home Assistant OS, `/etc/fstab` changes may not persist
- Use an add-on (Method 1) or automation (Method 3) instead
- Check if the mount point directory exists after reboot

### "Command not found" Errors

- Install required packages (cifs-utils or nfs-utils)
- On Home Assistant OS, you may need to use add-ons instead of manual mounting

### Connection Timeout

- Verify NAS IP address is correct
- Check network connectivity: `ping NAS_IP`
- Verify NAS share is accessible from other devices
- Check firewall rules

## Using the Mounted Share in Addons

Once mounted at the Home Assistant host level (e.g., `/media/nas`), it will be accessible to addons that have the appropriate mount points configured.

For Dispatcharr specifically:
- The addon has `map: - media:rw` which maps `/media` from the host
- So a share mounted at `/media/nas` on the host will be at `/media/nas` in the container
- Configure Dispatcharr to use `/media/nas` for media storage

## Security Notes

- **Password in fstab**: Consider using a credentials file instead:
  ```bash
  # Create credentials file
  sudo nano /etc/samba/credentials
  # Add:
  username=your_username
  password=your_password
  
  # Make it readable only by root
  sudo chmod 600 /etc/samba/credentials
  
  # Use in fstab:
  //NAS_IP/share_name /media/nas cifs credentials=/etc/samba/credentials,uid=1000,gid=1000 0 0
  ```

- **NFS Security**: Consider using NFSv4 with Kerberos for better security
- **Network Security**: Ensure your NAS and Home Assistant are on a trusted network

