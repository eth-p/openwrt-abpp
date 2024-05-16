#!/bin/ash
# ---------------------------------------------------------------------------------------------------------------------
# OpenWrt A/B Partition Project
# Copyright (C) 2024 eth-p
# MIT License
# https://github.com/eth-p/openwrt-abpp
# ---------------------------------------------------------------------------------------------------------------------
# Library script for fetching information about the A/B partition scheme.
# ---------------------------------------------------------------------------------------------------------------------
# Depends on packages:
#  * block-mount
#  * parted
#  * blkid
# ---------------------------------------------------------------------------------------------------------------------

# Function: abpp_partitions_scan
#
# Scans the drives and their partition tables to determine which partition is the active partition, which
# partition is the inactive partition, and which partition is the EFI partition.
abpp_partitions_scan() {
    # Find the boot storage device and active partition.
    ACTIVE_PARTITION="$(block info | grep 'MOUNT="/rom"' | cut -d' ' -f1 | sed 's/:$//')" || {
        echo "Unable to find active partition mount point." 1>&2
        echo "cannot find mount for '/rom'"
        return 20
    }

    BOOT_DEVICE="$(abpp_partitions_dev_to_diskdev "$ACTIVE_PARTITION")"

    # Read partition info to find the labels "OpenWRT-A" and "OpenWRT-B".
    local part_num start end size fs label more
    local part_a_num part_b_num
    while IFS=':' read -r part_num start end size fs label more; do
        case "$label" in
            "OpenWrt-A") part_a_num="$part_num" ;;
            "OpenWrt-B") part_b_num="$part_num" ;;
        esac
    done < <(parted "$BOOT_DEVICE" print --machine | sed 1d)

    if [ -z "${part_a_num:-}" ]; then
        echo "Unable to find partition with label 'OpenWrt-A'." 1>&2
        echo "cannot find partition 'A'"
        return 20
    fi

    if [ -z "${part_b_num:-}" ]; then
        echo "Unable to find partition with label 'OpenWrt-B'." 1>&2
        echo "cannot find partition 'B'"
        return 20
    fi

    # Determine which partition is the alternate partition.
    local active_num other_num
    active_num="$(abpp_partitions_dev_to_partnum "$ACTIVE_PARTITION")"
    if [ "$part_a_num" = "$active_num" ]; then
        other_num="$part_b_num"
        ACTIVE_PARTITION_LETTER="a"
        OTHER_PARTITION_LETTER="b"
    elif [ "$part_b_num" = "$active_num" ]; then
        other_num="$part_a_num"
        ACTIVE_PARTITION_LETTER="b"
        OTHER_PARTITION_LETTER="a"
    else
        echo "Unable to determine alternate partition." 1>&2
        echo "cannot determine alternate partition"
        return 20
    fi

    OTHER_PARTITION="$BOOT_DEVICE$other_num"

    # Get the EFI partition.
    EFI_PARTITION="$(
        blkid "$BOOT_DEVICE"* \
        | grep 'LABEL="kernel"' \
        | cut -d':' -f1
    )"
}

# Function: abpp_partitions_dev_to_diskdev
# Prints the disk identifier (e.g. `sda`) for the given device path.
#
# Parameters:
#   $1 -- The `/dev/...` device path.
abpp_partitions_dev_to_diskdev() {
    printf "%s" "$1" \
        | sed 's/[0-9]\{1,\}$//'
}

# Function: abpp_partitions_dev_to_diskdev
# Prints the partition number for the given device path.
#
# Parameters:
#   $1 -- The `/dev/...` device path.
abpp_partitions_dev_to_partnum() {
    printf "%s" "$1" \
        | grep -o '[0-9]\{1,\}$'
}

# Function: abpp_partitions_dev_to_partuuid
# Prints the partition UUID for the given partition device path.
#
# Parameters:
#   $1 -- The `/dev/...` device path.
abpp_partitions_dev_to_partuuid() {
    blkid "$1" 2>/dev/null \
        | grep -o 'PARTUUID="[0-9a-f-]*"' \
        | sed 's/PARTUUID=//; s/"//g' \
        || return 1
}
