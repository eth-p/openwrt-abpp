#=abpp
# --------
# This script creates a lightweight container.
# --------

# Prepare the container environment.
echo "Preparing container environment..."
abpp_container_firstrun

# Create the container.
echo "Creating container..."
abpp_container_create "$MOUNTED_ROOT"

