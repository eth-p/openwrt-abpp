#=abpp
# ---------------------------------------------------------------------------------------------------------------------
# OpenWrt A/B Partition Project
# Copyright (C) 2024 eth-p
# MIT License
# https://github.com/eth-p/openwrt-abpp
# ---------------------------------------------------------------------------------------------------------------------
# This upgrade stage will create a working directory within the new installation's filesystem.
#
# After completion, the following variables will be available to future stages:
#  * MOUNTED_WORKDIR          -- The absolute path to the working directory.
#  * MOUNTED_WORKDIR_REL      -- The absolute path to the working directory relative to the guest system.
# ---------------------------------------------------------------------------------------------------------------------

MOUNTED_WORKDIR_REL="/abpp-upgrading"
MOUNTED_WORKDIR="$MOUNTED_ROOT$MOUNTED_WORKDIR_REL"

# Create the directory for storing files.
if ! [ -d "$MOUNTED_WORKDIR" ]; then
    mkdir -p "$MOUNTED_WORKDIR"
fi

# Add the workdir location to the vars.
abpp_update_var \
    MOUNTED_WORKDIR \
    MOUNTED_WORKDIR_REL

# Print to show progress.
echo "OK."
