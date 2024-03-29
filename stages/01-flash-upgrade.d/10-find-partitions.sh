#=abpp
# ---------------------------------------------------------------------------------------------------------------------
# OpenWrt A/B Partition Project
# Copyright (C) 2024 eth-p
# MIT License
# https://github.com/eth-p/openwrt-abpp
# ---------------------------------------------------------------------------------------------------------------------
# This upgrade stage searches for the inactive (other) partition.
# After confirming with the user, OpenWrt will be installed to that partition.
#
# After completion, the following variables will be available to future stages:
#  * UPGRADE_TARGET_PARTITION -- The `/dev/...` path for inactive partition.
#  * UPGRADE_EFI_PARTITION    -- The `/dev/...` path for EFI partition.
# ---------------------------------------------------------------------------------------------------------------------

# Scan for the active and other partition.
echo "Scanning partition table..."
abpp_partitions_scan
echo "Scan complete."

# Print info about the active partition.
abpp_print "The current partition is detected to be %{CODE}%s%{R} (%s).\n" \
    "$ACTIVE_PARTITION" \
    "$ACTIVE_PARTITION_LETTER"

# Print info about the target partition.
abpp_print "OpenWrt will be installed to %{CODE}%s%{R} (%s).\n" \
    "$OTHER_PARTITION" \
    "$OTHER_PARTITION_LETTER"

# Print info about the EFI/bootloader partition.
abpp_print "The bootloader partition is %{CODE}%s%{R}.\n" \
    "$EFI_PARTITION"

# Confirm with the user.
abpp_prompt_confirm y "Is this correct?" || {
    abpp_print_error "Aborting."
    exit 99
}

# Save the target partition to a variable.
UPGRADE_TARGET_PARTITION="$OTHER_PARTITION"
UPGRADE_EFI_PARTITION="$EFI_PARTITION"
abpp_update_var \
    UPGRADE_TARGET_PARTITION \
    UPGRADE_EFI_PARTITION
