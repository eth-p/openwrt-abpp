#=abpp
# ---------------------------------------------------------------------------------------------------------------------
# OpenWrt A/B Partition Project
# Copyright (C) 2024 eth-p
# MIT License
# https://github.com/eth-p/openwrt-abpp
# ---------------------------------------------------------------------------------------------------------------------
# This upgrade stage migrates the user's current configuration to the newly-flashed installation.
# ---------------------------------------------------------------------------------------------------------------------

config_file="/etc/config/abpp"
migration_method="sysupgrade"

if [ -e "$config_file" ]; then
    if ! [ -f "$config_file" ] || ! [ -r "$config_file" ]; then
        echo "error: ABPP configuration is not a readable file: $config_file" 1>&2
        return 1
    fi
    if ! command -v uci >/dev/null 2>&1; then
        echo "error: uci is required to read $config_file" 1>&2
        return 1
    fi
    if ! uci -q -c "${config_file%/*}" export "${config_file##*/}" >/dev/null 2>&1; then
        echo "error: could not read UCI configuration: $config_file" 1>&2
        return 1
    fi

    if migration_method="$(uci -q -c "${config_file%/*}" get "${config_file##*/}.main.config_migration" 2>/dev/null)"; then
        :
    else
        migration_method="sysupgrade"
    fi
fi

case "$migration_method" in
sysupgrade)
    backup_filename="config.tar.gz"

    # Create the configuration backup.
    echo "Creating configuration backup with sysupgrade..."
    sysupgrade --create-backup "$MOUNTED_WORKDIR/$backup_filename"

    # Add an entry to uci-defaults to restore the backup on boot.
    echo "Preparing uci-default to restore configuration..."
    cat <<EOF >"$MOUNTED_ROOT/etc/uci-defaults/01_abpp_05_restore_config"
sysupgrade --restore-backup "$MOUNTED_WORKDIR_REL/$backup_filename" \\
    && rm "$MOUNTED_WORKDIR_REL/$backup_filename"
EOF
    ;;
rsync)
    if ! command -v rsync >/dev/null 2>&1; then
        echo "error: rsync is required when config_migration is set to 'rsync'." 1>&2
        return 1
    fi

    # The trailing slash copies /etc contents, including dot-files. Keep the
    # target release's package-manager configuration, world file, and banners.
    echo "Synchronizing /etc with rsync..."
    if rsync -a \
        --exclude-from="$SCRIPTS/rsync-excludes.txt" \
        /etc/ "$MOUNTED_ROOT/etc/"; then
        :
    else
        status=$?
        echo "error: failed to synchronize /etc with rsync." 1>&2
        return "$status"
    fi
    ;;
*)
    echo "error: invalid config_migration value '$migration_method'; expected 'sysupgrade' or 'rsync'." 1>&2
    return 1
    ;;
esac
