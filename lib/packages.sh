#!/bin/ash
# -----------------------------------------------------------------------------
# OpenWrt A/B Partition Project
# Copyright (C) 2024 eth-p
# https://github.com/eth-p/openwrt-abpp
# -----------------------------------------------------------------------------
# Library script for fetching information about packages.
# -----------------------------------------------------------------------------
# Depends on packages:
#  * opkg (built-in)
# -----------------------------------------------------------------------------

__abpp_packages_list_installed() {
    printf "%s\n" "$1"/*.list \
        | grep -o '/[^/]\{1,\}$' \
        | sed 's#^/##; s#\.list$##'
}

__abpp_packages_remove_nonunique() {
    # Removes all packages which appear more than once.
    #  * sort + uniq to count.
    #  * keep lines with only 1 occurrence.
    #  * remove count.

    sort \
        | uniq -c \
        | grep '^[ \t]\{1,\}1 ' \
        | sed 's/^[ \t]\{1,\}1 //'
}

abpp_packages_resolve_dependencies() {
    while read -r package; do
        if [ "${1:-}" = "--append" ]; then
            printf "%s\n" "$package"
        fi
        grep '^Depends: ' "/usr/lib/opkg/info/$package.control" || true
    done \
        | sed 's/^Depends: //' \
        | sed 's/([^)]\{1,\})//' \
        | sed 's/, /,/g' \
        | tr ',' '\n' \
        | sort -u
}

abpp_packages_resolve_provides() {
    while read -r package; do
        if [ "${1:-}" = "--append" ]; then
            printf "%s\n" "$package"
        fi
        grep '^Provides: ' "/usr/lib/opkg/info/$package.control" || true
    done \
        | sed 's/^Provides: //' \
        | sed 's/([^)]\{1,\})//' \
        | sed 's/, /,/g' \
        | tr ',' '\n' \
        | sort -u
}

abpp_packages_list_all_installed() {
    __abpp_packages_list_installed /usr/lib/opkg/info
}

abpp_packages_list_baseimage_installed() {
    __abpp_packages_list_installed /rom/usr/lib/opkg/info
}

abpp_packages_list_user_installed() {
    # Updates to packages may cause base image packages to appear in overlay.
    # Instead, we use set subtraction (ALL-BASE) to find packages NOT in the
    # base image.
    { 
        abpp_packages_list_all_installed
        abpp_packages_list_baseimage_installed
    } | __abpp_packages_remove_nonunique
}

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

