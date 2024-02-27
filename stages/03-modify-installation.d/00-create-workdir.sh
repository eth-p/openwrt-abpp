#=abpp
# --------
# This script creates a working directory for storing files in the
# mounted target partition.
# --------

MOUNTED_WORKDIR_REL="/abpp-upgrading"
MOUNTED_WORKDIR="$MOUNTED_ROOT$MOUNTED_WORKDIR_REL"

# Create the directory for storing files.
if ! [ -d "$MOUNTED_WORKDIR" ]; then
    mkdir -p "$MOUNTED_WORKDIR"
fi

# Add the workdir location to the vars.
abpp_update_var \
    MOUNTED_WORKDIR \
    MOUNTED_WORKDIR_REL

# Print to show progress.
echo "OK."

