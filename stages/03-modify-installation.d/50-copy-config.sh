#=abpp
# ---------------------------------------------------------------------------------------------------------------------
# OpenWrt A/B Partition Project
# Copyright (C) 2024 eth-p
# MIT License
# https://github.com/eth-p/openwrt-abpp
# ---------------------------------------------------------------------------------------------------------------------
# This upgrade stage will store a backup of the user's current configuration on the newly-flashed installation.
# It will also add a uci-defaults script to restore the backup on first boot.
# ---------------------------------------------------------------------------------------------------------------------

backup_filename="config.tar.gz"

# Create the configuration backup.
echo "Creating configuration backup..."
sysupgrade --create-backup "$MOUNTED_WORKDIR/$backup_filename"

# Add an entry to uci-defaults to restore the backup on boot.
echo "Preparing uci-default to restore configuration..."
cat <<EOF >"$MOUNTED_ROOT/etc/uci-defaults/01_abpp_05_restore_config"
sysupgrade --restore-backup "$MOUNTED_WORKDIR_REL/$backup_filename" \\
    && rm "$MOUNTED_WORKDIR_REL/$backup_filename"
EOF
