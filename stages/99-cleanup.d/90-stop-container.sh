#=abpp
# ---------------------------------------------------------------------------------------------------------------------
# OpenWrt A/B Partition Project
# Copyright (C) 2024 eth-p
# MIT License
# https://github.com/eth-p/openwrt-abpp
# ---------------------------------------------------------------------------------------------------------------------
# This upgrade stage attempts to destroy the container used earlier.
# ---------------------------------------------------------------------------------------------------------------------

# Exit early if the container runtime was never prepared.
if ! [ -d "$CONTAINER_RUNDIR" ]; then
    exit 0
fi

# Exit early if the container is not alive.
if ! abpp_container_alive "$MOUNTED_ROOT"; then
    exit 0
fi

# Attempt to destroy the container.
echo "Destroying container..."
abpp_container_destroy "$MOUNTED_ROOT"
echo "Container destroyed successfully."
