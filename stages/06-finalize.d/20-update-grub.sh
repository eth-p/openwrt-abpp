#=abpp
# ---------------------------------------------------------------------------------------------------------------------
# OpenWrt A/B Partition Project
# Copyright (C) 2024 eth-p
# MIT License
# https://github.com/eth-p/openwrt-abpp
# ---------------------------------------------------------------------------------------------------------------------
# This upgrade stage updates the GRUB configuration to use the newly-flashed OpenWrt installation as the default.
# ---------------------------------------------------------------------------------------------------------------------

grubcfg_current="$EFI_ROOT/boot/grub/grub.cfg"
grubcfg_new="$EFI_ROOT/boot/grub/grub.cfg-new"
grubcfg_old="$EFI_ROOT/boot/grub/grub.cfg.old"

# Scan for the active and other partition.
echo "Scanning partition table..."
abpp_partitions_scan
echo "Scan complete."

# Get the PARTUUID of the current and new installations.
echo "Getting partition UUIDs..."
old_partuuid="$(abpp_partitions_dev_to_partuuid "$ACTIVE_PARTITION")"
new_partuuid="$(abpp_partitions_dev_to_partuuid "$UPGRADE_TARGET_PARTITION")"

# Get the versions of the current and new installations.
echo "Getting version information..."
old_version="$("$SCRIPTS"/libexec/release-info VERSION)"
new_version="$({ source "$MOUNTED_ROOT/etc/os-release" && echo "$VERSION"; })"

# Get the letters for the current and new installations.
old_letter="$ACTIVE_PARTITION_LETTER"
new_letter="$OTHER_PARTITION_LETTER"

# Create a copy of the old GRUB config.
echo "Backing up old grub config..."
cp "$grubcfg_current" "$grubcfg_old"

# Generate a new GRUB config from the template.
echo "Generating grub config..."
"$SCRIPTS"/libexec/template-grub "$grubcfg_current" 2 \
    -- VERSION="$new_version" LETTER="$new_letter" PARTITION="PARTUUID=$new_partuuid" \
    -- VERSION="$old_version" LETTER="$old_letter" PARTITION="PARTUUID=$old_partuuid" \
    >"$grubcfg_new"

# Print the generated config.
abpp_print "%{CODE}"
sed 's/^/ | /' "$grubcfg_new"
abpp_print "%{R}"

# Ask the user if they would like to edit the config.
if ! abpp_prompt_confirm y "Apply this config?"; then
    if ! abpp_prompt_confirm y "Edit the config?"; then
        abpp_print_error "Aborted!"
        exit 99
    fi

    abpp_prompt_editor "$grubcfg_new"
fi

# Apply the config.
echo "Applying config..."
mv "$grubcfg_new" "$grubcfg_current"
