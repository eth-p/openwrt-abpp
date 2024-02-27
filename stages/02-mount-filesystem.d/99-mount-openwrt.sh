#=abpp
# --------
# This script mounts the OpenWrt installation from the target partition.
# Mounting includes the ROM partition, data partition, and overlay.
# --------

MOUNTED_ROOT="$ABPP_WORKDIR/other"

# Create the directory for the mountpoint.
if ! [ -d "$MOUNTED_ROOT" ]; then
    mkdir -p "$MOUNTED_ROOT"
fi

# Attempt to mount the directory.
echo "Mounting other installation..."
"$SCRIPTS"/libexec/mount-openwrt \
    "$UPGRADE_TARGET_PARTITION" \
    "$MOUNTED_ROOT"

# Add the mount point location to the vars.
abpp_update_var MOUNTED_ROOT

