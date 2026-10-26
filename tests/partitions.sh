#!/usr/bin/env bash
set -euo pipefail

SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPTS/lib/partitions.sh"

assert_equal() {
    local expected="$1" actual="$2" description="$3"
    if [ "$actual" != "$expected" ]; then
        printf 'FAIL: %s (expected %s, got %s)\n' "$description" "$expected" "$actual" >&2
        exit 1
    fi
}

assert_equal "/dev/sda" "$(abpp_partitions_dev_to_diskdev /dev/sda10)" "legacy disk path"
assert_equal "/dev/nvme0n1" "$(abpp_partitions_dev_to_diskdev /dev/nvme0n1p10)" "NVMe disk path"
assert_equal "/dev/mmcblk0" "$(abpp_partitions_dev_to_diskdev /dev/mmcblk0p128)" "MMC disk path"
assert_equal "128" "$(abpp_partitions_dev_to_partnum /dev/nvme0n1p128)" "multi-digit partition number"
assert_equal "/dev/sda11" "$(abpp_partitions_diskdev_to_partdev /dev/sda 11)" "legacy target path"
assert_equal "/dev/nvme0n1p11" "$(abpp_partitions_diskdev_to_partdev /dev/nvme0n1 11)" "NVMe target path"
assert_equal "/dev/mmcblk0p11" "$(abpp_partitions_diskdev_to_partdev /dev/mmcblk0 11)" "MMC target path"

block() {
    printf '%s: TYPE=squashfs MOUNT="/rom"\n' "$ACTIVE_DEVICE"
}

parted() {
    assert_equal "$EXPECTED_DISK" "$1" "parted disk argument"
    cat <<'PARTITIONS'
BYT;
/dev/mock:128035676160B:scsi:512:512:gpt:Mock disk:;
1:262144B:17039359B:16777216B:fat32:kernel:boot, esp;
10:17825792B:12582912000B:12565086208B:ext4:OpenWrt-A:;
11:12582912001B:23068643328B:10485731327B:ext4:OpenWrt-B:;
99:23068643329B:128035676000B:104966332671B:ext4:Persistent:;
128:17408B:261631B:244224B::BIOS boot:;
PARTITIONS
}

blkid() {
    printf '%s: LABEL="kernel" TYPE="vfat"\n' \
        "$(abpp_partitions_diskdev_to_partdev "$EXPECTED_DISK" 1)"
}

scan_and_assert() {
    ACTIVE_DEVICE="$1"
    EXPECTED_DISK="$2"
    local target="$3"

    abpp_partitions_scan
    assert_equal "$EXPECTED_DISK" "$BOOT_DEVICE" "detected boot disk"
    assert_equal "$ACTIVE_DEVICE" "$ACTIVE_PARTITION" "detected active partition"
    assert_equal "$target" "$OTHER_PARTITION" "detected alternate partition"
    assert_equal "a" "$ACTIVE_PARTITION_LETTER" "active A label"
    assert_equal "b" "$OTHER_PARTITION_LETTER" "alternate B label"
    assert_equal "$(abpp_partitions_diskdev_to_partdev "$EXPECTED_DISK" 1)" "$EFI_PARTITION" "detected EFI partition"
}

scan_and_assert /dev/nvme0n1p10 /dev/nvme0n1 /dev/nvme0n1p11
scan_and_assert /dev/mmcblk0p10 /dev/mmcblk0 /dev/mmcblk0p11
scan_and_assert /dev/sda10 /dev/sda /dev/sda11

printf 'Partition path checks passed.\n'
