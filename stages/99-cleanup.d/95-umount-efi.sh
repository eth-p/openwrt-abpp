#=abpp
# --------
# This script unmounts the new OpenWrt installation.
# --------

# Exit early if there is no mount.
if [ -z "${EFI_ROOT:-}" ]; then
    exit 0
fi

# Unmount the other installation.
if grep -F "$EFI_ROOT" /proc/mounts &>/dev/null; then
    echo "Unmounting EFI partition..."
    umount "$EFI_ROOT"
fi

# Remove the mountpoint directory.
if [ -d "$EFI_ROOT" ]; then
    rmdir "$EFI_ROOT"
fi

