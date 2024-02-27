#!/bin/ash
# -----------------------------------------------------------------------------
# OpenWrt A/B Partition Project
# Copyright (C) 2024 eth-p
# https://github.com/eth-p/openwrt-abpp
# -----------------------------------------------------------------------------
# Library script for printing in user-interactive contexts.
# -----------------------------------------------------------------------------

__abpp_print_rpat="$(printf '
    s/%%{R}/\x1B[m/g;
    s/%%{WARN}/\x1B[33m/g;
    s/%%{ERR}/\x1B[31m/g;
    s/%%{OK}/\x1B[32m/g;
    s/%%{CODE}/\x1B[35m/g;
    s/%%{ASK}/\x1B[36m/g;
    s/%%{STAGE}/\x1B[34m/g;
')"

if ! [ -t 1 ]; then
    __abpp_print_rpat="$({
        printf "%s" "$__abpp_print_rpat" \
	    | sed 's#/[^/]\{1,\}/g;#//;#g'
    })"
fi

abpp_print() {
    local pat="$(printf "%s\n" "$1" | sed "$__abpp_print_rpat")"
    shift
    printf "$pat" "$@"
}

abpp_print_sep() {
    abpp_print "%{$1}"
    printf "%80s" "" | tr ' ' '-'
    abpp_print "%{R}\n"
}

abpp_print_notice() {
    local color="$1"
    local color_ansi="$(abpp_print "%{$color}")"
    shift
    abpp_print_sep "$color"
    printf "$color_ansi%s\n" "$@" | sed "s/%{R}/%{R}%{$color}/g; $__abpp_print_rpat"
    abpp_print_sep "$color"
    abpp_print "%{R}"
}

abpp_print_stage() {
    abpp_print "%{STAGE}==> %s%{R}\n" "$1"
}

abpp_print_error() {
    abpp_print "%{ERR}!!! %s%{R}\n" "$@"
}
