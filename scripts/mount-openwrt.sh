#!/bin/bash
# -----------------------------------------------------------------------------
# OpenWRT A/B Partition Project
# Copyright (C) 2024 eth-p
# https://github.com/eth-p/openwrt-abpp
# -----------------------------------------------------------------------------
set -euo pipefail

DEVICE="${1:-}"
MOUNT="${2:-}"

# Check for correct command usage.
if [ -z "$DEVICE" ] || [ -z "$MOUNT" ]; then
    echo "usage: $0 [device] [mountpoint]" 1>&2
    exit 10
fi

# Determine the filesystem size.
FS_SIZE="$(
    unsquashfs -s "$DEVICE" \
        | grep -o 'Filesystem size [0-9]\{1,\} bytes' \
        | grep -o '[0-9]\{1,\}'
)"

# Find the offset for the hidden data partition.
# https://lxr.openwrt.org/source/fstools/libfstools/rootdisk.c#L122
FS_OFFSET="$(expr '(' "$FS_SIZE" + 65535 ')' / 65536 '*' 65536)"

# Create a loopback block device.
LO_DEVICE="$(losetup --find --offset="$FS_OFFSET" --show "$DEVICE")"
LO_FS=f2fs

# Create the initial filesystem if one doesn't exist.
if [ "$(dd if="$LO_DEVICE" bs=1024 count=2 2>/dev/null | tr -d '\0' | wc -c)" -eq 0 ]; then
    "mkfs.${LO_FS}" "$LO_DEVICE"
fi

# Mount the ROM (immutable) filesystem.
[ -d "$MOUNT" ] || mkdir -p "$MOUNT"
mount -o ro "$DEVICE" "$MOUNT"
mount -o ro "$DEVICE" "$MOUNT/rom"

# Mount the data (mutable) filesystem.
[ -d "$MOUNT/overlay" ] || mkdir -p "$MOUNT/overlay"
mount "$LO_DEVICE" "$MOUNT/overlay"

# Mount the overlay.
[ -d "$MOUNT/overlay/upper" ] || mkdir -p "$MOUNT/overlay/upper"
[ -d "$MOUNT/overlay/work" ]  || mkdir -p "$MOUNT/overlay/work"

mount -t overlay "overlayfs:$MOUNT" \
    -o rw,noatime,xino=off,lowerdir="$MOUNT",upperdir="$MOUNT/overlay/upper",workdir="$MOUNT/overlay/work" \
    "$MOUNT"
