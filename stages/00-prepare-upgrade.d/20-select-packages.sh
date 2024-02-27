#=abpp
# ---------------------------------------------------------------------------------------------------------------------
# OpenWrt A/B Partition Project
# Copyright (C) 2024 eth-p
# MIT License
# https://github.com/eth-p/openwrt-abpp
# ---------------------------------------------------------------------------------------------------------------------
# This upgrade stage compiles a list of user-installed packages and asks the user which ones to carry over to the
# updated installation.
#
# After completion, the following variables will be available to future stages:
#  * UPGRADE_PACKAGES_FILE    -- Path to the file containing the user's selection.
# ---------------------------------------------------------------------------------------------------------------------

echo "Collecting list of installed packages..."
packages="$("$SCRIPTS"/libexec/packages-info user-minimal)"
echo "The following packages were found:"

# Print the packages.
abpp_print "%{CODE}"
abpp_print "%s\n" "$packages" | sed 's/^/ * /'
abpp_print "%{R}"

# Describe the purpose.
echo ""
echo "These packages will be installed on version $UPGRADE_NEW_VERSION."

# Write the package list to a file.
UPGRADE_PACKAGES_FILE="$ABPP_WORKDIR/to-install-packages.txt"
abpp_update_var UPGRADE_PACKAGES_FILE
printf "%s\n" \
    "# The following packages will be installed on verison $UPGRADE_NEW_VERSION." \
    "# You may add or remove any packages below:" \
    "$packages" \
    >"$UPGRADE_PACKAGES_FILE"

# Ask the user if they would like to make changes.
if ! abpp_prompt_confirm y "Is this ok?"; then
    abpp_prompt_editor "$UPGRADE_PACKAGES_FILE"
fi
