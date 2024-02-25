#!/bin/ash
# -----------------------------------------------------------------------------
# OpenWrt A/B Partition Project
# Copyright (C) 2024 eth-p
# https://github.com/eth-p/openwrt-abpp
# -----------------------------------------------------------------------------
# Library script for creating a lightweight container for working under the
# root of an alternate partition.
# -----------------------------------------------------------------------------
# Depends on packages:
#  * block-mount
#  * unshare
#  * nsenter
#  * dumb-init
# -----------------------------------------------------------------------------
CONTAINER_RUNDIR="/tmp/abpp"

abpp_container_firstrun() {
    if [ -d "$CONTAINER_RUNDIR" ]; then
        return 0
    fi

    # Create the container runtime directory structure.
    mkdir -p "$CONTAINER_RUNDIR"

    # Create a private mount so we can bind namespaces.
    mount --bind "$CONTAINER_RUNDIR" "$CONTAINER_RUNDIR"
    mount --make-private "$CONTAINER_RUNDIR"
}

abpp_container_get_rundir() {
    local mount="$1"
    printf "%s/%s" \
        "$CONTAINER_RUNDIR" \
        "$(echo "$mount" | sed 's/[^A-Za-z0-9]/-/g')"
}

abpp_container_alive() {
    if [ -z "${1:-}" ]; then
        echo "usage: abpp_container_alive [mountpoint]" 1>&2
        return 10
    fi

    local mount="$1"
    local rundir="$(abpp_container_get_rundir "$mount")"

    # Return error if the container is not alive.
    [ -d "$rundir" ]          || return 1
    [ -f "$rundir/host.pid" ] || return 1
    kill -0 "$(cat "$rundir/host.pid")" &>/dev/null || return 1

    # The container is probably alive. 
    return 0
}

abpp_container_sessions() {
    if [ -z "${1:-}" ]; then
        echo "usage: abpp_container_alive [mountpoint]" 1>&2
        return 10
    fi

    local mount="$1"
    local rundir="$(abpp_container_get_rundir "$mount")"

    # Iterate through the sessions and print any live ones.
    local session session_pid
    local status=1
    for session in "$rundir/sessions"/*; do
        if [ "$session" = "$rundir/sessions/*" ]; then break; fi
        session_pid="$(cat "$session")"
        if kill -0 "$session_pid" 2>/dev/null; then
            echo "session_pid"
            status=0
        else
            rm "$session"
        fi
    done

    # Return 0 if any sessions were alive.
    return $status
}

abpp_container_create() {
    if [ -z "${1:-}" ]; then
        echo "usage: abpp_container_create [mountpoint]" 1>&2
        return 10
    fi

    local mount="$1"
    local rundir="$(abpp_container_get_rundir "$mount")"

    # Do nothing if the container is already alive.
    if abpp_container_alive "$mount"; then
        return 0
    fi

    # Create the directory structure.
    mkdir -p "$rundir" "$rundir/ns" "$rundir/sessions"
    touch "$rundir/host.pid" \
        "$rundir/ns/mnt" \
        "$rundir/ns/pid" \
        "$rundir/ns/ipc" \
        "$rundir/ns/cgroup"

    # Create a target for pivot_root.
    if ! [ -d "$mount/.parent" ]; then
        mkdir -p "$mount/.parent"
    fi

    # Create the namespaces and use dumb-init as the init process.
    #  * Create namespaces.
    #  * Mount procfs to /proc under the container root.
    #  * Pivot mount namespace's root to the container root.
    #  * Sleep forever.
    #  * Record the PID of unshare, which will forward signals.
    unshare \
        --fork \
        --mount="$rundir/ns/mnt" \
        --pid="$rundir/ns/pid" \
        --ipc="$rundir/ns/ipc" \
        --cgroup="$rundir/ns/cgroup" \
        /usr/sbin/dumb-init /bin/ash -c \
        "mount -t proc procfs '$mount/proc' \
            && pivot_root '$mount' '$mount/.parent' \
            && while true; do sleep 1; done" &

    echo "$!" > "$rundir/host.pid"

    # Wait until it's possible to enter the container.
    while true; do
        sleep 1
        if __abpp_container_enter "$mount" /bin/true; then
            break
        fi
    done
}

abpp_container_destroy() {
    if [ -z "${1:-}" ]; then
        echo "usage: abpp_container_destroy [mountpoint]" 1>&2
        return 10
    fi

    local mount="$1"
    local rundir="$(abpp_container_get_rundir "$mount")"

    # Kill the init process if it's alive.
    if [ -f "$rundir/host.pid" ]; then
        kill -INT "$(cat "$rundir/host.pid")" || true
    fi
    
    # Wait until it's no longer possible to enter the container.
    while true; do
        sleep 1
        if ! __abpp_container_enter "$mount" /bin/true 2>/dev/null; then
            break
        fi
    done

    # Remove session PIDs, if any.
    local file
    for file in "$rundir/sessions"/*; do
        if [ "$file" = "$rundir/sessions/*" ]; then break; fi
        rm "$file"
    done

    # Unmount namespaces.
    local ns
    for ns in mnt pid ipc cgroup; do
        if ! [ -f "$rundir/ns/$ns" ]; then continue; fi
        if ! umount "$rundir/ns/$ns"; then continue; fi
        rm "$rundir/ns/$ns" || true
    done

    # Remove host PID file.
    if [ -f "$rundir/host.pid" ]; then rm "$rundir/host.pid"; fi

    # Remove directories.
    local dir
    for dir in ns sessions; do
        rmdir "$rundir/$dir" || true
    done

    rmdir "$rundir" || true
}

__abpp_container_enter() {
    if [ -z "${1:-}${2:-}" ]; then
        echo "usage: abpp_container_enter [mountpoint] [command] [args...]" 1>&2
        return 10
    fi

    local mount="$1"
    local rundir="$(abpp_container_get_rundir "$mount")"
    shift

    # Enter the container's namespaces.   
    nsenter \
        --mount="$rundir/ns/mnt" \
        --pid="$rundir/ns/pid" \
        --ipc="$rundir/ns/ipc" \
        --cgroup="$rundir/ns/cgroup" \
        --wdns="/" \
        "$@"
}

abpp_container_enter() {
    if [ -z "${1:-}${2:-}" ]; then
        echo "usage: abpp_container_enter [mountpoint] [command] [args...]" 1>&2
        return 10
    fi

    local mount="$1"
    local rundir="$(abpp_container_get_rundir "$mount")"

    # Add this process to the session list.
    echo "$$" >"$rundir/sessions/$$"

    # Enter the container's namespaces.
    local status=0
    if ! __abpp_container_enter "$@"; then
        status=$?
    fi

    # Remove this process from the session list.
    rm "$rundir/sessions/$$"
    return $status
}

