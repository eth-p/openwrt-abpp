#=abpp
# --------
# This script downloads the selected version of OpenWrt.
# --------

# Download the selected version of OpenWrt.
echo "Downloading OpenWrt..."
"$SCRIPTS"/libexec/download-upgrade \
    "$UPGRADE_NEW_VERSION" \
    "$ABPP_TEMPDIR"

# Set variables pointing to the downloaded files.
UPGRADE_ROOTFS_FILE="$ABPP_TEMPDIR/rootfs.img.gz"
UPGRADE_KERNEL_FILE="$ABPP_TEMPDIR/kernel.bin"
abpp_update_var \
    UPGRADE_ROOTFS_FILE \
    UPGRADE_KERNEL_FILE

