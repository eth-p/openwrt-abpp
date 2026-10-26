#!/bin/ash
# ---------------------------------------------------------------------------------------------------------------------
# OpenWrt A/B Partition Project
# Copyright (C) 2024 eth-p
# MIT License
# https://github.com/eth-p/openwrt-abpp
# ---------------------------------------------------------------------------------------------------------------------
# Library script for creating a lightweight container for working under the root of an alternate partition.
# ---------------------------------------------------------------------------------------------------------------------
# Depends on packages:
#  * block-mount
#  * unshare
#  * nsenter
#  * dumb-init
# ---------------------------------------------------------------------------------------------------------------------
CONTAINER_RUNDIR="/tmp/abpp"

# Function: abpp_container_firstrun
# Prepares the system to run openwrt-abpp's implementation of Linux containers.
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

# Function: abpp_container_get_rundir
# Prints the runtime directory for the given container.
#
# Parameters:
#   $1 -- The root directory of the container.
abpp_container_get_rundir() {
    local mount="$1"
    printf "%s/%s" \
        "$CONTAINER_RUNDIR" \
        "$(echo "$mount" | sed 's/[^A-Za-z0-9]/-/g')"
}

# Function: abpp_container_alive
# Checks if the given container is running.
#
# Parameters:
#   $1 -- The root directory of the container.
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
    # A live unshare process is not enough: the target root may have been
    # unmounted or removed while the process remained. Verify namespace entry.
    __abpp_container_enter "$mount" /bin/ash -c : >/dev/null 2>&1
}

# Function: abpp_container_sessions
# Prints a list of active sessions within the given container.
#
# Parameters:
#   $1 -- The root directory of the container.
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

# Function: abpp_container_create
# Creates a new container.
#
# Parameters:
#   $1 -- The root directory of the container.
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

    # Do not replace namespace files while an old unshare process still owns
    # them. The caller must destroy this unusable container first.
    if [ -f "$rundir/host.pid" ]; then
        local host_pid
        host_pid="$(cat "$rundir/host.pid")"
        if kill -0 "$host_pid" 2>/dev/null; then
            echo "error: container process $host_pid is running but its namespace is unusable." 1>&2
            echo "Destroy the stale container before creating it again." 1>&2
            return 1
        fi
    fi

    # Remove namespace mountpoints left by an interrupted container startup.
    # A namespace file may still be a mountpoint even after its host process
    # has exited, which prevents the files from being recreated below.
    if [ -d "$rundir/ns" ]; then
        local ns
        for ns in mnt pid ipc cgroup; do
            umount "$rundir/ns/$ns" 2>/dev/null || true
            rm -f "$rundir/ns/$ns"
        done
    fi

    # Create the directory structure.
    mkdir -p "$rundir" "$rundir/ns" "$rundir/sessions"
    touch "$rundir/host.pid" \
        "$rundir/ns/mnt" \
        "$rundir/ns/pid" \
        "$rundir/ns/ipc" \
        "$rundir/ns/cgroup"

    # Create a target for pivot_root.
    local created_parent=false
    if ! [ -d "$mount/.parent" ]; then
        mkdir -p "$mount/.parent"
        created_parent=true
    fi
    mkdir -p "$mount/proc" "$mount/dev"

    # Keep the namespace init alive with a host-root sleep process; the target
    # root may not contain a sleep executable.
    unshare \
        --fork \
        --mount="$rundir/ns/mnt" \
        --pid="$rundir/ns/pid" \
        --ipc="$rundir/ns/ipc" \
        --cgroup="$rundir/ns/cgroup" \
        /usr/sbin/dumb-init /bin/ash -c \
        "set -e
            sleep 2147483 &
            keeper=\$!
            trap 'kill \"\$keeper\" 2>/dev/null || true' EXIT
            trap 'exit 0' TERM INT
            mount --make-rprivate /
            mount --bind '$mount' '$mount'
            mount --bind /dev '$mount/dev'
            mount -t proc procfs '$mount/proc'
            cd '$mount'
            pivot_root . .parent
            cd /
            wait \"\$keeper\"" &

    echo "$!" > "$rundir/host.pid"

    # Wait until it's possible to enter the container.
    while true; do
        sleep 1
        if __abpp_container_enter "$mount" /bin/ash -c :; then
            echo "Container ready."
            break
        fi
        if ! kill -0 "$(cat "$rundir/host.pid")" 2>/dev/null; then
            echo "error: container process exited while starting." 1>&2
            for ns in mnt pid ipc cgroup; do
                umount "$rundir/ns/$ns" 2>/dev/null || true
                rm -f "$rundir/ns/$ns"
            done
            rm -f "$rundir/host.pid"
            rmdir "$rundir/ns" "$rundir/sessions" "$rundir" 2>/dev/null || true
            if [ "$created_parent" = true ]; then
                rmdir "$mount/.parent" 2>/dev/null || true
            fi
            return 1
        fi
    done
}

# Function: abpp_container_destroy
# Destroys an existing container.
#
# Parameters:
#   $1 -- The root directory of the container.
abpp_container_destroy() {
    if [ -z "${1:-}" ]; then
        echo "usage: abpp_container_destroy [mountpoint]" 1>&2
        return 10
    fi

    local mount="$1"
    local rundir="$(abpp_container_get_rundir "$mount")"

    # Kill the init process if it's alive.
    if [ -f "$rundir/host.pid" ]; then
        __abpp_container_enter "$mount" /bin/ash -c 'kill -TERM 1' || true
        kill -INT "$(cat "$rundir/host.pid")" || true
    fi

    # Wait until it's no longer possible to enter the container.
    while true; do
        sleep 1
        if ! __abpp_container_enter "$mount" /bin/ash -c : 2>/dev/null; then
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

# Function: __abpp_container_enter
# Runs an executable inside a container.
#
# Parameters:
#   $1 -- The root directory of the container.
#   $2 -- The path (within the container's root) of the executable.
#   .. -- The executable's arguments.
__abpp_container_enter() {
    if [ -z "${1:-}${2:-}" ]; then
        echo "usage: __abpp_container_enter [mountpoint] [command] [args...]" 1>&2
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

# Function: abpp_container_enter
# Runs an executable inside a container.
#
# Parameters:
#   $1 -- The root directory of the container.
#   $2 -- The path (within the container's root) of the executable.
#   .. -- The executable's arguments.
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
    __abpp_container_enter "$@" || {
        status=$?
    }

    # Remove this process from the session list.
    rm "$rundir/sessions/$$"
    return $status
}
