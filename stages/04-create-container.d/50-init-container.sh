#=abpp
# ---------------------------------------------------------------------------------------------------------------------
# OpenWrt A/B Partition Project
# Copyright (C) 2024 eth-p
# MIT License
# https://github.com/eth-p/openwrt-abpp
# ---------------------------------------------------------------------------------------------------------------------
# This upgrade stage will create a lightweight container to run programs within the newly-flashed OpenWrt installation.
# Future stages can run executables within it like so:
#     abpp_container_enter "$MOUNTED_ROOT"
# ---------------------------------------------------------------------------------------------------------------------

# Prepare the container environment.
echo "Preparing container environment..."
abpp_container_firstrun

# Create the container.
echo "Creating container..."
abpp_container_create "$MOUNTED_ROOT"
