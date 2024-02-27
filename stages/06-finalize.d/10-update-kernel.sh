#=abpp
# ---------------------------------------------------------------------------------------------------------------------
# OpenWrt A/B Partition Project
# Copyright (C) 2024 eth-p
# MIT License
# https://github.com/eth-p/openwrt-abpp
# ---------------------------------------------------------------------------------------------------------------------
# This upgrade stage copies the downloaded Linux kernel to the EFI partition.
# ---------------------------------------------------------------------------------------------------------------------

# Figure out which kernel file to replace.
echo "Scanning partition table..."
abpp_partitions_scan
echo "Scan complete."

# Replace the kernel file.
echo "Copying kernel..."
cp "$UPGRADE_KERNEL_FILE" "$EFI_ROOT/boot/vmlinuz-${OTHER_PARTITION_LETTER}"
