#!/bin/ash
# ---------------------------------------------------------------------------------------------------------------------
# OpenWrt A/B Partition Project
# Copyright (C) 2024 eth-p
# MIT License
# https://github.com/eth-p/openwrt-abpp
# ---------------------------------------------------------------------------------------------------------------------
# Library script for prompting in user-interactive contexts.
# ---------------------------------------------------------------------------------------------------------------------

# Function: abpp_prompt_confirm
# Asks the user to confirm an action.
#
# Parameters:
#   $1 -- The default action.
#   $2 -- The prompt message.
abpp_prompt_confirm() {
    local response
    while true; do
        abpp_print "%{ASK}%s [yn]%{R} " "$2"
        read -r response
        case "$response" in
            y|Y) return 0;;
            n|N) return 1;;
        esac
    done
}

# Function: abpp_prompt_editor
# Opens the user's editor, defaulting to vim or nano if unspecified.
#
# Parameters:
#   $1 -- The file to edit.
abpp_prompt_editor() {
    local file="$1"
    if [ -n "${EDITOR:-}" ]; then
        "$EDITOR" "$file" 1>/dev/tty
    elif command -v vim &>/dev/null; then
        vim -nN --cmd "set bs=2" -u /dev/null "$file" 1>/dev/tty
    elif command -v nano &>/dev/null; then
        nano "$file" 1>/dev/tty
    else
        echo "error: cannot find editor program" 1>&2
        return 1
    fi
}

# Function: abpp_prompt_confirm
# Asks the user to select a single item out of a list.
#
# Parameters:
#   $1 -- A newline-delimited list of selection options.
abpp_prompt_selection() {
    # Write the list of options to a file.
    local file
    file="$(mktemp)"
    {
        echo "# Select an option by replacing '[ ]' with '[x]'"
        printf "%s\n" "$1" | sed 's/^/[ ] /'
    } >"$file"

    # Open the editor.
    abpp_prompt_editor "$file" || {
        rm "$file"
        return 1
    }

    # Select the response.
    local selection
    selection="$(grep '^\[x\] ' "$file" | sed 's/^\[x\] *//')" || {
        rm "$file"
        return 2
    }

    rm "$file"

    # Ensure exactly 1 response was given.
    test "$(printf "%s" "$selection" | wc -l)" -eq 1

    # Print the response.
    printf "%s\n" "$selection"
    return 0
}

