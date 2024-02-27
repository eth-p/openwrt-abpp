#=abpp
# --------
# This script uses the sysupgrade tool to create a configuration backup.
# The backup will then be copied to the mounted target partition.
# --------

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

