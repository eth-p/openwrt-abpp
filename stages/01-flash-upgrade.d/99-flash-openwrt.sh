#=abpp
# ---------------------------------------------------------------------------------------------------------------------
# OpenWrt A/B Partition Project
# Copyright (C) 2024 eth-p
# MIT License
# https://github.com/eth-p/openwrt-abpp
# ---------------------------------------------------------------------------------------------------------------------
# This upgrade stage flashes the downloaded rootfs to the inactive partition.
# ---------------------------------------------------------------------------------------------------------------------

# Confirm with the user.
abpp_print "OpenWrt version %{CODE}%s%{R} will be flashed to %{CODE}%s%{R}.\n" \
    "$UPGRADE_NEW_VERSION" \
    "$UPGRADE_TARGET_PARTITION"

abpp_print "%{WARN}All existing system and user data will be destroyed.%{R}\n"
abpp_prompt_confirm y "Proceed?" || {
    abpp_print_error "Aborting."
    exit 99
}

# Flash to the target partition.
echo "Flashing OpenWrt..."
gunzip -c "$UPGRADE_ROOTFS_FILE" | dd of="$UPGRADE_TARGET_PARTITION" conv=fsync
echo "Flashed successfully."
