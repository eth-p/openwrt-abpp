#=abpp
# --------
# This script destroys the lightweight container.
# --------

# Exit early if the container runtime was never prepared.
if ! [ -d "$CONTAINER_RUNDIR" ]; then
    exit 0
fi

# Exit early if the container is not alive.
if ! abpp_container_alive "$MOUNTED_ROOT"; then
    exit 0
fi

# Attempt to destroy the container.
echo "Destroying container..."
abpp_container_destroy "$MOUNTED_ROOT"
echo "Container destroyed successfully."

