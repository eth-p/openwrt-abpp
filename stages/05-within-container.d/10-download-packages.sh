#=abpp
# ---------------------------------------------------------------------------------------------------------------------
# OpenWrt A/B Partition Project
# Copyright (C) 2024 eth-p
# MIT License
# https://github.com/eth-p/openwrt-abpp
# ---------------------------------------------------------------------------------------------------------------------
# This upgrade stage downloads the user's selected packages on the new installation.
# It will also add a uci-defaults script to install them (and subsequently reboot) on first boot.
# ---------------------------------------------------------------------------------------------------------------------

packages_dirname="/packages"
packageslist_filename="packages.list"
packages_log_filename="packages-install.log"

# Ensure /var/lock exists within the new installation.
if ! [ -d "$MOUNTED_ROOT/var/lock" ]; then
    mkdir "$MOUNTED_ROOT/var/lock"
fi

# Create the packages directory.
if ! [ -d "$MOUNTED_WORKDIR/$packages_dirname" ]; then
    echo "Creating packages directory..."
    mkdir "$MOUNTED_WORKDIR/$packages_dirname"
fi

# Copy the packages list.
echo "Copying desired package list..."
abpp_packages_filter_excluded \
    <"$UPGRADE_PACKAGES_FILE" \
    >"$MOUNTED_WORKDIR/$packageslist_filename"

# Select the package manager in the target installation.
package_manager="$(abpp_container_enter "$MOUNTED_ROOT" /bin/ash -c '
    if command -v apk >/dev/null 2>&1; then
        printf apk
    elif command -v opkg >/dev/null 2>&1; then
        printf opkg
    fi
')"
if [ -z "$package_manager" ]; then
    echo "error: neither apk nor opkg is installed in the target installation." 1>&2
    exit 127
fi
echo "Target package manager: $package_manager"
if [ "$package_manager" = apk ]; then
    # OpenWrt buildbot packages are not individually signed by default; apk
    # authenticated their checksums through the trusted repository index when
    # fetching them. Permit those verified local archives during offline install.
    package_install_command="add --allow-untrusted --no-network --repositories-file /dev/null --force-non-repository"
    package_archive_pattern="*.apk"
else
    package_install_command="install"
    package_archive_pattern="*.ipk"
fi

# Refresh package indexes within the container.
echo "Fetching available package information with $package_manager..."
if [ "$package_manager" = apk ]; then
    if ! TMPDIR= abpp_container_enter "$MOUNTED_ROOT" /bin/ash -c '
        update_log="$(mktemp)"
        apk update >"$update_log" 2>&1
        status=$?
        cat "$update_log"
        if grep -Eq "wgetSSL error|unexpected end of file|unavailable" "$update_log"; then
            echo "error: APK repository refresh failed; check the target clock and CA bundle." 1>&2
            rm -f "$update_log"
            exit 1
        fi
        rm -f "$update_log"
        exit "$status"
    '; then
        echo "error: could not refresh APK repositories; package archives were not downloaded." 1>&2
        return 1
    fi
else
    if ! TMPDIR= abpp_container_enter "$MOUNTED_ROOT" \
        "$package_manager" update; then
        echo "error: could not refresh opkg repositories; package archives were not downloaded." 1>&2
        return 1
    fi
fi
echo "Package information fetched."

# Download the packages within the container. `apk fetch` writes package archives,
# while opkg's download-only install uses the current directory.
echo "Downloading selected packages..."
if [ "$package_manager" = apk ]; then
    TMPDIR= abpp_container_enter "$MOUNTED_ROOT" /bin/ash -c "\
        set -e; \
        cd '$MOUNTED_WORKDIR_REL/$packages_dirname'; \
        apk fetch --recursive \
            --output '$MOUNTED_WORKDIR_REL/$packages_dirname' \
            \$(grep -v '^#' '$MOUNTED_WORKDIR_REL/$packageslist_filename'); \
        set -- *.apk; \
        [ -f \"\$1\" ] || { echo 'error: apk fetch did not produce any package archives.' 1>&2; exit 1; }
    "
    echo "APK package archives downloaded."
else
    TMPDIR= abpp_container_enter "$MOUNTED_ROOT" /bin/ash -c "\
        cd '$MOUNTED_WORKDIR_REL/$packages_dirname';      \
        cat '$MOUNTED_WORKDIR_REL/$packageslist_filename' \
            | xargs opkg install --download-only
    "
    echo "OPKG package archives downloaded."
fi

# Add an entry to uci-defaults to install the packages on boot.
echo "Preparing uci-default to install packages..."
touch "$MOUNTED_ROOT/etc/uci-defaults/99_abpp_reboot"
cat <<EOF >"$MOUNTED_ROOT/etc/uci-defaults/01_abpp_01_install_packages"
set -o pipefail
{
    echo "Starting staged package installation..."
    printf '<6>ABPP: Starting staged package installation.\n' >>/dev/kmsg
    if ! $package_manager $package_install_command "$MOUNTED_WORKDIR_REL/$packages_dirname"/$package_archive_pattern; then
        echo "error: failed to install staged packages; leaving them in $MOUNTED_WORKDIR_REL/$packages_dirname" 1>&2
        exit 1
    fi
} 2>&1 | awk '
    {
        package = \$0
        sub(/^[[:space:]]*/, "", package)
        sub(/^\([0-9]+\/[0-9]+\)[[:space:]]*/, "", package)
    }
    /(^|[[:space:]])(Installing|Upgrading)[[:space:]]/ {
        sub(/^.*(Installing|Upgrading)[[:space:]]+/, "", package)
        sub(/[[:space:]].*$/, "", package)
        progress = sprintf("Installing package %s", package)
        printf "<6>ABPP: %s\n", progress >> "/dev/kmsg"
        close("/dev/kmsg")
        print progress
        fflush()
    }
    { print; fflush() }
' | tee "$MOUNTED_WORKDIR_REL/$packages_log_filename" >/dev/console

if [ "$?" -ne 0 ]; then
    exit 1
fi

if ! echo 'reboot -d 10' >/etc/uci-defaults/99_abpp_reboot; then
    printf '%s\n' "error: could not schedule the final reboot." \
        | tee -a "$MOUNTED_WORKDIR_REL/$packages_log_filename" >>/dev/console
    exit 1
fi
printf '%s\n' "Package installation complete; reboot scheduled." \
    | tee -a "$MOUNTED_WORKDIR_REL/$packages_log_filename" >>/dev/console
printf '<6>ABPP: Package installation complete; reboot scheduled.\n' >>/dev/kmsg
if ! rm -rf "$MOUNTED_WORKDIR_REL"; then
    echo "error: could not remove $MOUNTED_WORKDIR_REL after package installation." >/dev/console
    exit 1
fi
EOF
echo "First-boot package installation script created."
