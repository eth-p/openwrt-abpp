#=abpp
# ---------------------------------------------------------------------------------------------------------------------
# OpenWrt A/B Partition Project
# Copyright (C) 2024 eth-p
# MIT License
# https://github.com/eth-p/openwrt-abpp
# ---------------------------------------------------------------------------------------------------------------------
# This upgrade stage attempts to mount the filesystem of the newly-flashed OpenWrt installation.
# If necessary, it will initialize the mutable F2FS partition used for its overlay.
#
# After completion, the following variables will be available to future stages:
#  * MOUNTED_ROOT             -- The path to the newly-flashed installation's root directory.
# ---------------------------------------------------------------------------------------------------------------------

MOUNTED_ROOT="$ABPP_WORKDIR/other"

# Create the directory for the mountpoint.
if ! [ -d "$MOUNTED_ROOT" ]; then
    mkdir -p "$MOUNTED_ROOT"
fi

# Attempt to mount the directory.
echo "Mounting OpenWrt filesystems..."
"$SCRIPTS"/libexec/mount-openwrt \
    "$UPGRADE_TARGET_PARTITION" \
    "$MOUNTED_ROOT"

# Add the mount point location to the vars.
abpp_update_var MOUNTED_ROOT
