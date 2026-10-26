#=abpp
# ---------------------------------------------------------------------------------------------------------------------
# OpenWrt A/B Partition Project
# Copyright (C) 2024 eth-p
# MIT License
# https://github.com/eth-p/openwrt-abpp
# ---------------------------------------------------------------------------------------------------------------------
# Install required tools once the user has confirmed the version and package
# selection and the release has downloaded, before partition discovery needs
# those tools.
# ---------------------------------------------------------------------------------------------------------------------

abpp_packages_ensure_installed \
    blkid \
    block-mount \
    dumb-init \
    kmod-fs-squashfs \
    kmod-fs-vfat \
    losetup \
    nsenter \
    parted \
    rsync \
    squashfs-tools-unsquashfs \
    unshare
