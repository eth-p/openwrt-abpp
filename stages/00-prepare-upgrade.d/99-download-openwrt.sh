#=abpp
# ---------------------------------------------------------------------------------------------------------------------
# OpenWrt A/B Partition Project
# Copyright (C) 2024 eth-p
# MIT License
# https://github.com/eth-p/openwrt-abpp
# ---------------------------------------------------------------------------------------------------------------------
# This upgrade stage downloads the kernel and rootfs for the target OpenWrt version.
#
# After completion, the following variables will be available to future stages:
#  * UPGRADE_ROOTFS_FILE      -- Path to the downloaded OpenWrt rootfs image.
#  * UPGRADE_KERNEL_FILE      -- Path to the downloaded OpenWrt kernel image.
# ---------------------------------------------------------------------------------------------------------------------

# Download the selected version of OpenWrt.
echo "Downloading OpenWrt ${UPGRADE_NEW_VERSION}..."
"$SCRIPTS"/libexec/download-upgrade \
    "$UPGRADE_NEW_VERSION" \
    "$ABPP_TEMPDIR"

# Set variables pointing to the downloaded files.
UPGRADE_ROOTFS_FILE="$ABPP_TEMPDIR/rootfs.img.gz"
UPGRADE_KERNEL_FILE="$ABPP_TEMPDIR/kernel.bin"
abpp_update_var \
    UPGRADE_ROOTFS_FILE \
    UPGRADE_KERNEL_FILE
