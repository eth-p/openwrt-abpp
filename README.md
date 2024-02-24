# OpenWRT A/B Partition Project

>[!note]
>This is a work in progress.

>[!warning]
>This is designed for x86_64 systems.

## Installation

TODO detailed guide. TL;DR:

Initial setup:

 - Flash `squashfs-combined` to the internal drive.
 - Download `squashfs-rootfs`.
 - Repartition the internal drive:
   - `2`: FAT, 128 MiB --- Stores these scripts.
   - `10`: Linux, 50% remaining space --- Flash the rootfs to this partition.
   - `11`: Linux, 50% remaining space --- Flash the rootfs to this partition.

Required packages within OpenWRT:

```
losetup
block-mount
kmod-fs-vfat
kmod-fs-squashfs
squashfs-tools-unsquashfs
unshare
fake-root
```