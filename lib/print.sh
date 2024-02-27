#!/bin/ash
# ---------------------------------------------------------------------------------------------------------------------
# OpenWrt A/B Partition Project
# Copyright (C) 2024 eth-p
# MIT License
# https://github.com/eth-p/openwrt-abpp
# ---------------------------------------------------------------------------------------------------------------------
# Library script for printing in user-interactive contexts.
# ---------------------------------------------------------------------------------------------------------------------

# Initialize the sed replacement pattern for color codes.
__abpp_print_rpat="$(printf '
    s/%%{R}/\x1B[m/g;
    s/%%{WARN}/\x1B[33m/g;
    s/%%{ERR}/\x1B[31m/g;
    s/%%{OK}/\x1B[32m/g;
    s/%%{CODE}/\x1B[35m/g;
    s/%%{ASK}/\x1B[36m/g;
    s/%%{STAGE}/\x1B[34m/g;
')"

# If not printing to a terminal, strip out the colors instead of printing them.
if ! [ -t 1 ]; then
    __abpp_print_rpat="$({
        printf "%s" "$__abpp_print_rpat" \
            | sed 's#/[^/]\{1,\}/g;#//;#g'
    })"
fi

# Function: abpp_print
# A wrapper around `printf` that supports color substitutions.
#
# Parameters:
#   $1 -- The printf format.
#   .. -- The format arguments.
abpp_print() {
    local pat="$(printf "%s\n" "$1" | sed "$__abpp_print_rpat")"
    shift
    printf "$pat" "$@"
}

# Function: abpp_print_sep
# Prints an 80-character separator.
#
# Parameters:
#   $1 -- The color of the separator.
abpp_print_sep() {
    abpp_print "%{$1}"
    printf "%80s" "" | tr ' ' '-'
    abpp_print "%{R}\n"
}

# Function: abpp_print_notice
# Prints a large, separator-delimited wall of text.
#
# Parameters:
#   .. -- The contents of the notice.
abpp_print_notice() {
    local color="$1"
    local color_ansi="$(abpp_print "%{$color}")"
    shift
    abpp_print_sep "$color"
    printf "$color_ansi%s\n" "$@" | sed "s/%{R}/%{R}%{$color}/g; $__abpp_print_rpat"
    abpp_print_sep "$color"
    abpp_print "%{R}"
}

# Function: abpp_print_stage
# Prints an indicator showing where an installation stage started.
#
# Parameters:
#   $1 -- The name of the stage.
abpp_print_stage() {
    abpp_print "%{STAGE}==> %s%{R}\n" "$1"
}

# Function: abpp_print_error
# Prints an indicator with an error message.
#
# Parameters:
#   .. -- Each line to print.
abpp_print_error() {
    abpp_print "%{ERR}!!! %s%{R}\n" "$@"
}
