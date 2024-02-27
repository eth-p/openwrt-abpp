#!/bin/ash
# ---------------------------------------------------------------------------------------------------------------------
# OpenWrt A/B Partition Project
# Copyright (C) 2024 eth-p
# MIT License
# https://github.com/eth-p/openwrt-abpp
# ---------------------------------------------------------------------------------------------------------------------
# Library script for fetching information about installed packages.
# ---------------------------------------------------------------------------------------------------------------------
# Depends on packages:
#  * opkg (built-in)
# ---------------------------------------------------------------------------------------------------------------------

# Function: __abpp_packages_list_installed
# Lists all the packages that can be found under `opkg`'s info directory.
#
# Parameters:
#   $1 -- The directory to scan.
__abpp_packages_list_installed() {
    printf "%s\n" "$1"/*.list \
        | grep -o '/[^/]\{1,\}$' \
        | sed 's#^/##; s#\.list$##'
}

# Function: __abpp_packages_remove_nonunique
# Removes all packages which appear more than once.
#
# Parameters:
#   &0 -- The packages to filter.
__abpp_packages_remove_nonunique() {
    #  * sort + uniq to count.
    #  * keep lines with only 1 occurrence.
    #  * remove count.

    sort \
        | uniq -c \
        | grep '^[ \t]\{1,\}1 ' \
        | sed 's/^[ \t]\{1,\}1 //'
}

# Function: abpp_packages_resolve_dependencies
# Prints the set of dependencies for all provided packages.
#
# Parameters:
#   &0 -- The packages to query.
abpp_packages_resolve_dependencies() {
    while read -r package; do
        grep '^Depends: ' "/usr/lib/opkg/info/$package.control" || true
    done \
        | sed 's/^Depends: //' \
        | sed 's/([^)]\{1,\})//' \
        | sed 's/, /,/g' \
        | tr ',' '\n' \
        | sort -u
}

# Function: abpp_packages_resolve_provides
# Prints the set of features from all provided packages.
#
# Parameters:
#   &0 -- The packages to query.
abpp_packages_resolve_provides() {
    while read -r package; do
        grep '^Provides: ' "/usr/lib/opkg/info/$package.control" || true
    done \
        | sed 's/^Provides: //' \
        | sed 's/([^)]\{1,\})//' \
        | sed 's/, /,/g' \
        | tr ',' '\n' \
        | sort -u
}

# Function: abpp_packages_list_all_installed
# Prints a list of all the installed packages.
abpp_packages_list_all_installed() {
    __abpp_packages_list_installed /usr/lib/opkg/info
}

# Function: abpp_packages_list_baseimage_installed
# Prints a list of all packages that came installed with the rootfs.
abpp_packages_list_baseimage_installed() {
    __abpp_packages_list_installed /rom/usr/lib/opkg/info
}

# Function: abpp_packages_list_user_installed
# Prints a list of all packages installed or updated by the user.
abpp_packages_list_user_installed() {
    # Updates to packages may cause base image packages to appear in overlay.
    # Instead, we use set subtraction (ALL-BASE) to find packages NOT in the
    # base image.
    {
        abpp_packages_list_all_installed
        abpp_packages_list_baseimage_installed
    } | __abpp_packages_remove_nonunique
}

# Function: abpp_packages_list_user_installed
# Prints the list of all packages directly installed by the user.
abpp_packages_list_user_installed_minimal() {
    # Resolve package dependencies and provides in such a way that
    # the only packages which do not appear more than once are
    # packages that the user installed.
    #
    # This may accidentally include packages that are installed
    # as an alternate implementation of a library. Without having
    # support for set operations in ash, it's not possible to fix this.
    {
        abpp_packages_list_all_installed
        abpp_packages_list_baseimage_installed
        abpp_packages_list_user_installed | abpp_packages_resolve_dependencies
        abpp_packages_list_all_installed  | abpp_packages_resolve_provides | sed 'p;p'
    }   | __abpp_packages_remove_nonunique \
        | grep -vwF 'kernel'
}
