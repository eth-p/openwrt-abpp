#=abpp
# ---------------------------------------------------------------------------------------------------------------------
# OpenWrt A/B Partition Project
# Copyright (C) 2024 eth-p
# MIT License
# https://github.com/eth-p/openwrt-abpp
# ---------------------------------------------------------------------------------------------------------------------
# This upgrade stage mounts the EFI partition.
#
# After completion, the following variables will be available to future stages:
#  * EFI_ROOT                 -- The path to the mounted EFI partition's filesystem.
# ---------------------------------------------------------------------------------------------------------------------

EFI_ROOT="$ABPP_WORKDIR/efi"

# Create the directory for the mountpoint.
if ! [ -d "$EFI_ROOT" ]; then
    mkdir -p "$EFI_ROOT"
fi

# Attempt to mount the directory.
echo "Mounting bootloader filesystem..."
mount -t vfat "$UPGRADE_EFI_PARTITION" "$EFI_ROOT"

# Add the mount point location to the vars.
abpp_update_var EFI_ROOT
