#=abpp
# ---------------------------------------------------------------------------------------------------------------------
# OpenWrt A/B Partition Project
# Copyright (C) 2024 eth-p
# MIT License
# https://github.com/eth-p/openwrt-abpp
# ---------------------------------------------------------------------------------------------------------------------
# This upgrade stage attempts to unmount the EFI partition.
# ---------------------------------------------------------------------------------------------------------------------

# Exit early if there is no mount.
if [ -z "${EFI_ROOT:-}" ]; then
    exit 0
fi

# Unmount the other installation.
if grep -F "$EFI_ROOT" /proc/mounts &>/dev/null; then
    echo "Unmounting bootloader filesystem..."
    umount "$EFI_ROOT"
fi

# Remove the mountpoint directory.
if [ -d "$EFI_ROOT" ]; then
    rmdir "$EFI_ROOT"
fi
