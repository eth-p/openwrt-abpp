#=abpp
# --------
# This script mounts the OpenWrt installation from the target partition.
# Mounting includes the ROM partition, data partition, and overlay.
# --------

EFI_ROOT="$ABPP_WORKDIR/efi"

# Create the directory for the mountpoint.
if ! [ -d "$EFI_ROOT" ]; then
    mkdir -p "$EFI_ROOT"
fi

# Attempt to mount the directory.
echo "Mounting bootloader partition..."
mount -t vfat "$UPGRADE_EFI_PARTITION" "$EFI_ROOT"

# Add the mount point location to the vars.
abpp_update_var EFI_ROOT

