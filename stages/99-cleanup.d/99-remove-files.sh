#=abpp
# ---------------------------------------------------------------------------------------------------------------------
# OpenWrt A/B Partition Project
# Copyright (C) 2024 eth-p
# MIT License
# https://github.com/eth-p/openwrt-abpp
# ---------------------------------------------------------------------------------------------------------------------
# This upgrade stage attempts to remove files created during the upgrade process.
# ---------------------------------------------------------------------------------------------------------------------

if [ -n "${UPGRADE_ROOTFS_FILE:-}" ] && [ -f "${UPGRADE_ROOTFS_FILE}" ]; then
    echo "Removing rootfs.img.gz..."
    rm "$UPGRADE_ROOTFS_FILE"
fi

if [ -n "${UPGRADE_KERNEL_FILE:-}" ] && [ -f "${UPGRADE_KERNEL_FILE}" ]; then
    echo "Removing kernel.bin..."
    rm "$UPGRADE_KERNEL_FILE"
fi

if [ -n "${UPGRADE_PACKAGES_FILE:-}" ] && [ -f "${UPGRADE_PACKAGES_FILE}" ]; then
    echo "Removing packages file..."
    rm "$UPGRADE_PACKAGES_FILE"
fi

if [ -n "${ABPP_TEMPDIR:-}" ] && [ -d "${ABPP_TEMPDIR}" ]; then
    echo "Removing temporary directory..."
    rmdir "$ABPP_TEMPDIR"
fi
