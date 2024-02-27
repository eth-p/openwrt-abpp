#=abpp
# ---------------------------------------------------------------------------------------------------------------------
# OpenWrt A/B Partition Project
# Copyright (C) 2024 eth-p
# MIT License
# https://github.com/eth-p/openwrt-abpp
# ---------------------------------------------------------------------------------------------------------------------
# This upgrade stage attempts to remove all the leftover files in `/tmp`.
# ---------------------------------------------------------------------------------------------------------------------

echo "Removing leftover files..."
rm -rf "$MOUNTED_ROOT/tmp"/* 2>/dev/null || true
