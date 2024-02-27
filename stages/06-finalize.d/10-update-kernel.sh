#=abpp
# --------
# This script mounts the OpenWrt installation from the target partition.
# Mounting includes the ROM partition, data partition, and overlay.
# --------

# Figure out which kernel file to replace.
echo "Scanning partition table..."
abpp_partitions_scan
echo "Scan complete."

# Replace the kernel file.
echo "Copying kernel..."
cp "$UPGRADE_KERNEL_FILE" "$EFI_ROOT/boot/vmlinuz-${OTHER_PARTITION_LETTER}"

