#=abpp
# --------
# This script asks the user which version of OpenWrt to install.
# --------

# Get the current version.
current_version="$("$SCRIPTS"/libexec/release-info VERSION)"

# Find a list of supported versions for the board/architecture.
echo "Downloading version list..."
versions="$("$SCRIPTS"/libexec/openwrt-versions --supported)"

# Select the latest version.
selected_version="$(printf '%s' "$versions" | tail -n1)"
abpp_print "Currently running version %{CODE}%s%{R}.\n" "$current_version"
abpp_print "The latest supported version is %{CODE}%s%{R}.\n" "$selected_version"

# Ask the user if this is okay.
# If not, have them select which version.
if ! abpp_prompt_confirm y "Install this version?"; then
    selected_version="$(abpp_prompt_selection "$versions")"
fi

# Warn if the versions are the same.
if [ "$current_version" = "$selected_version" ]; then
    abpp_prompt_confirm y "The selected version is the same as the current version. Continue?" || exit 1
fi

# Save the selected version to a variable for later reference.
UPGRADE_NEW_VERSION="$selected_version"
abpp_update_var UPGRADE_NEW_VERSION

