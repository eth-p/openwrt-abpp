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
#  * apk or opkg (built-in)
# ---------------------------------------------------------------------------------------------------------------------

# Function: abpp_packages_manager
# Prints the package manager for the given root, preferring `apk` when both are
# installed.
abpp_packages_manager() {
    local root="${1:-}"
    if [ -n "$root" ]; then
        if [ -f "$root/lib/apk/db/installed" ]; then
            printf '%s\n' apk
            return 0
        elif [ -d "$root/usr/lib/opkg/info" ]; then
            printf '%s\n' opkg
            return 0
        fi
        echo "error: no supported package database found in $root" 1>&2
        return 127
    fi

    if command -v apk >/dev/null 2>&1; then
        printf '%s\n' apk
    elif command -v opkg >/dev/null 2>&1; then
        printf '%s\n' opkg
    else
        echo "error: neither apk nor opkg is installed" 1>&2
        return 127
    fi
}

# Function: abpp_packages_ensure_installed
# Installs any missing packages using the active package manager.
#
# Parameters:
#   &0 -- Package names to ensure are installed.
abpp_packages_ensure_installed() {
    local manager installed package missing

    if [ "$#" -eq 0 ]; then
        echo "error: no packages specified for installation." 1>&2
        return 10
    fi

    manager="$(abpp_packages_manager)" || return $?
    case "$manager" in
        apk)
            if ! installed="$(apk info)"; then
                echo "error: could not query installed APK packages." 1>&2
                return 1
            fi
            ;;
        opkg)
            if ! installed="$(opkg list-installed)"; then
                echo "error: could not query installed opkg packages." 1>&2
                return 1
            fi
            ;;
        *)
            echo "error: unsupported package manager: $manager" 1>&2
            return 127
            ;;
    esac

    missing=""
    for package in "$@"; do
        case "$package" in
            ""|*[!a-zA-Z0-9._+-]*)
                echo "error: invalid package name: $package" 1>&2
                return 10
                ;;
        esac
        if ! printf '%s\n' "$installed" | awk -v package="$package" '$1 == package { found = 1 } END { exit !found }'; then
            missing="${missing}${missing:+ }$package"
        fi
    done

    if [ -z "$missing" ]; then
        return 0
    fi

    echo "Installing required packages: $missing" 1>&2
    set -- $missing
    case "$manager" in
        apk)
            if ! apk update || ! apk add "$@"; then
                echo "error: failed to install required packages: $missing" 1>&2
                return 1
            fi
            ;;
        opkg)
            if ! opkg update || ! opkg install "$@"; then
                echo "error: failed to install required packages: $missing" 1>&2
                return 1
            fi
            ;;
    esac
}

# Function: __abpp_packages_excluded_list
# Prints the configured package exclusions, if any.
#
# Parameters:
#   $1 -- Optional path to the UCI configuration file (defaults to /etc/config/abpp).
__abpp_packages_excluded_list() {
    local config_file="${1:-/etc/config/abpp}"
    local config_dir="${config_file%/*}"
    local config_name="${config_file##*/}"
    local values

    if ! [ -e "$config_file" ]; then
        return 0
    fi
    if ! [ -f "$config_file" ] || ! [ -r "$config_file" ]; then
        echo "error: ABPP package configuration is not a readable file: $config_file" 1>&2
        return 1
    fi
    if ! command -v uci >/dev/null 2>&1; then
        echo "error: uci is required to read $config_file" 1>&2
        return 1
    fi
    if ! uci -q -c "$config_dir" export "$config_name" >/dev/null 2>&1; then
        echo "error: could not read UCI configuration: $config_file" 1>&2
        return 1
    fi

    if ! values="$(uci -q -c "$config_dir" get "$config_name.main.exclude_package" 2>/dev/null)"; then
        return 0
    fi

    if ! printf '%s\n' "$values" | awk '
        {
            for (i = 1; i <= NF; i++) {
                if ($i !~ /^[[:alnum:]_.+-]+$/) {
                    printf "error: invalid package name in ABPP exclusions: %s\n", $i > "/dev/stderr"
                    invalid = 1
                } else {
                    print $i
                }
            }
        }
        END { exit invalid }
    '; then
        return 1
    fi
}

# Function: __abpp_packages_filter_excluded_list
# Removes configured exclusions and comments/blank lines from a package list.
#
# Parameters:
#   &0 -- The package names to filter.
#   $1 -- The configured excluded package names.
__abpp_packages_filter_excluded_list() {
    local package
    local excluded="$1"

    while IFS= read -r package || [ -n "$package" ]; do
        case "$package" in
            ""|\#*) continue ;;
        esac
        case "
$excluded
" in
            *"
$package
"*) continue ;;
        esac
        printf '%s\n' "$package"
    done
}

# Function: __abpp_packages_filter_installed_list
# Removes packages that are not present in the active installed-package list.
#
# Parameters:
#   &0 -- The package names to filter.
#   $1 -- The active installed package names.
__abpp_packages_filter_installed_list() {
    local package
    local installed="$1"

    while IFS= read -r package || [ -n "$package" ]; do
        case "$package" in
            ""|\#*) continue ;;
        esac
        case "
$installed
" in
            *"
$package
"*) printf '%s\n' "$package" ;;
        esac
    done
}

# Function: abpp_packages_filter_excluded
# Removes configured exclusions and comments/blank lines from a package list.
#
# Parameters:
#   &0 -- The package names to filter.
#   $1 -- Optional path to the UCI configuration file (defaults to /etc/config/abpp).
abpp_packages_filter_excluded() {
    local excluded
    excluded="$(__abpp_packages_excluded_list "${1:-/etc/config/abpp}")" || return $?
    __abpp_packages_filter_excluded_list "$excluded"
}

# Function: __abpp_packages_list_installed
# Lists all the packages installed in the given root.
#
# Parameters:
#   $1 -- The root directory to query.
__abpp_packages_list_installed() {
    local root="$1"
    local installed
    case "$(abpp_packages_manager "$root")" in
        apk)
            if [ "$root" = "/" ]; then
                if ! installed="$(apk list --installed --manifest)"; then
                    echo "error: could not query installed APK packages." 1>&2
                    return 1
                fi
                printf '%s\n' "$installed" | awk 'NF { print $1 }'
                return 0
            fi
            awk 'substr($0, 1, 2) == "P:" { print substr($0, 3) }' \
                "$root/lib/apk/db/installed"
            ;;
        opkg)
            printf "%s\n" "$root/usr/lib/opkg/info"/*.list \
                | grep -o '/[^/]\{1,\}$' \
                | sed 's#^/##; s#\.list$##'
            ;;
    esac
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
    local manager
    manager="$(abpp_packages_manager)"

    while read -r package; do
        if [ "$manager" = apk ]; then
            awk -v package="$package" '
                substr($0, 1, 2) == "P:" { found = (substr($0, 3) == package) }
                found && substr($0, 1, 2) == "D:" { print substr($0, 3); exit }
            ' /lib/apk/db/installed
        else
            grep '^Depends: ' "/usr/lib/opkg/info/$package.control" || true
        fi
    done \
        | sed 's/^Depends: //' \
        | sed 's/([^)]\{1,\})//' \
        | sed 's/, /,/g' \
        | tr ' ,' '\n' \
        | sort -u
}

# Function: abpp_packages_resolve_provides
# Prints the set of features from all provided packages.
#
# Parameters:
#   &0 -- The packages to query.
abpp_packages_resolve_provides() {
    local manager
    manager="$(abpp_packages_manager)"

    while read -r package; do
        if [ "$manager" = apk ]; then
            awk -v package="$package" '
                substr($0, 1, 2) == "P:" { found = (substr($0, 3) == package) }
                found && substr($0, 1, 2) == "p:" { print substr($0, 3); exit }
            ' /lib/apk/db/installed
        else
            grep '^Provides: ' "/usr/lib/opkg/info/$package.control" || true
        fi
    done \
        | sed 's/^Provides: //' \
        | sed 's/([^)]\{1,\})//' \
        | sed 's/, /,/g' \
        | tr ' ,' '\n' \
        | sort -u
}

# Function: abpp_packages_list_all_installed
# Prints a list of all the installed packages.
abpp_packages_list_all_installed() {
    __abpp_packages_list_installed /
}

# Function: abpp_packages_list_baseimage_installed
# Prints a list of all packages that came installed with the rootfs.
abpp_packages_list_baseimage_installed() {
    __abpp_packages_list_installed /rom
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
    local excluded
    local all_installed
    local base_installed

    excluded="$(__abpp_packages_excluded_list)" || return $?
    all_installed="$(
        abpp_packages_list_all_installed \
            | __abpp_packages_filter_excluded_list "$excluded"
    )" || return $?
    base_installed="$(
        abpp_packages_list_baseimage_installed \
            | __abpp_packages_filter_excluded_list "$excluded"
    )" || return $?

    # Resolve package dependencies and provides in such a way that
    # the only packages which do not appear more than once are
    # packages that the user installed.
    #
    # This may accidentally include packages that are installed
    # as an alternate implementation of a library. Without having
    # support for set operations in ash, it's not possible to fix this.
    {
        printf '%s\n' "$all_installed"
        printf '%s\n' "$base_installed"
        {
            printf '%s\n' "$all_installed"
            printf '%s\n' "$base_installed"
        } | grep -v '^$' | __abpp_packages_remove_nonunique | abpp_packages_resolve_dependencies
        printf '%s\n' "$all_installed" | grep -v '^$' | abpp_packages_resolve_provides | sed 'p;p'
    }   | __abpp_packages_remove_nonunique \
        | grep -vwF 'kernel' \
        | __abpp_packages_filter_installed_list "$all_installed" \
        | __abpp_packages_filter_excluded_list "$excluded"
}
