#=abpp
# ---------------------------------------------------------------------------------------------------------------------
# OpenWrt A/B Partition Project
# Copyright (C) 2024 eth-p
# MIT License
# https://github.com/eth-p/openwrt-abpp
# ---------------------------------------------------------------------------------------------------------------------
# This upgrade stage attempts to unmount the newly-flashed partition's filesystems.
# ---------------------------------------------------------------------------------------------------------------------

# Exit early if there is no mount.
if [ -z "${MOUNTED_ROOT:-}" ]; then
    exit 0
fi

# Unmount the other installation.
if grep -F "$MOUNTED_ROOT" /proc/mounts &>/dev/null; then
    echo "Unmounting OpenWrt filesystems..."
    "$SCRIPTS"/libexec/umount-openwrt \
        "$MOUNTED_ROOT"
fi

# Remove the mountpoint directory.
if [ -d "$MOUNTED_ROOT" ]; then
    rmdir "$MOUNTED_ROOT"
fi
