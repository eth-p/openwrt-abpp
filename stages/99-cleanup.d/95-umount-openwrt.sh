#=abpp
# --------
# This script unmounts the new OpenWrt installation.
# --------

# Exit early if there is no mount.
if [ -z "${MOUNTED_ROOT:-}" ]; then
    exit 0
fi

# Unmount the other installation.
if grep -F "$MOUNTED_ROOT" /proc/mounts &>/dev/null; then
    echo "Unmounting OpenWrt..."
    "$SCRIPTS"/libexec/umount-openwrt \
        "$MOUNTED_ROOT"
fi

# Remove the mountpoint directory.
if [ -d "$MOUNTED_ROOT" ]; then
    rmdir "$MOUNTED_ROOT"
fi

