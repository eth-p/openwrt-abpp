# OpenWrt A/B Partition Project
This is a project that enables [OpenWrt](https://openwrt.org/) to be installed using an A/B partition scheme.

>[!caution]
> The OpenWrt A/B Partition Project is designed for x86_64 systems.  
> It will *probably not work* for other architectures without modification.

## Requirements

* A Linux live USB stick with `wget`/`curl`, along with both `parted` and `fdisk`.
* A computer to install OpenWrt to, with at least 8 GiB of storage.

## Installation

The initial setup for OpenWrt A/B partitioning is entirely manual.  
Please follow these instructions carefully.

### Base OpenWrt Installation

(Start by booting up your device with the Linux live USB stick.)

First, you will need to download (or copy) both the `generic-squashfs-combined-efi` and
`generic-squashfs-rootfs` images.

```bash
wget "https://archive.openwrt.org/releases/23.05.1/targets/x86/64/openwrt-23.05.1-x86-64-generic-squashfs-combined-efi.img.gz"
wget "https://archive.openwrt.org/releases/23.05.1/targets/x86/64/openwrt-23.05.1-x86-64-generic-squashfs-rootfs.img.gz"
```

The next step is to identify the internal storage device to install OpenWrt on:

```bash
lsblk
# NAME      MAJ:MIN RM   SIZE RO TYPE MOUNTPOINTS
# loop0       7:0    0 766.5M  1 loop /run/archiso/airootfs
# sda         8:0    0  29.8G  0 disk
# ├─sda1      8:1    0    16M  0 part
# └─sda2      8:2    0  29.7G  0 part
# sdb         8:16   0   1.9G  0 disk
# ├─sdb1      8:17   0   917M  0 part
# └─sdb2      8:18   0    15G  0 part
```

If you are not sure which device is what, `ls -l /dev/disk/by-id` may help:

```bash
ls -l /dev/disk/by-id
# total 0
# lrwxrwxrwx 1 root root  9 Feb 27 13:00 ata-DEVICE_NAME_DEVICE_SERIAL -> ../../sda
# lrwxrwxrwx 1 root root  9 Feb 27 13:00 ata-DEVICE_NAME_DEVICE_SERIAL-part1 -> ../../sda1
# lrwxrwxrwx 1 root root  9 Feb 27 13:00 ata-DEVICE_NAME_DEVICE_SERIAL-part2 -> ../../sda2
# lrwxrwxrwx 1 root root  9 Feb 27 13:00 usb-USBSTICK_NAME_DEVICE_SERIAL -> ../../sdb
# lrwxrwxrwx 1 root root  9 Feb 27 13:00 usb-USBSTICK_NAME_DEVICE_SERIAL-part1 -> ../../sdb1
# lrwxrwxrwx 1 root root  9 Feb 27 13:00 usb-USBSTICK_NAME_DEVICE_SERIAL-part2 -> ../../sdb2
```

Once you determine which disk to install to, flash the uncompressed `-combined-efi` image to it:

```bash
gunzip -c *-combined-efi.img.gz | dd of=/dev/sda status=progress
```

### A/B OpenWrt Modification

With the base installation complete, you will need to modify it to support an A/B partition scheme.

First, you will need to update the partition table using `fdisk`.  
Remove partition 2 and replace it with the following three partitions:

| Partition ID | Size | Filesystem Type |
|:--|:--|:--|
| 2 | 200+ MiB | Microsoft basic data (type 11) |
| 10 | 50% remaining space | Linux filesystem (type 20) |
| 11 | 50% remaining space | Linux filesystem (type 20) |

Next, use `parted` to rename each of the partitions:

| Partition ID | Name |
|:--|:--|
| 2 | Persistent |
| 10 | OpenWrt-A |
| 11 | OpenWrt-B |

>[!important]
> Partition `10` and `11` **must** be named `OpenWrt-A` and `OpenWrt-B` respectively.  
> The partition name is used by `abupgrade` to detect which partition to flash.

You will need the partition UUIDs for `OpenWrt-A` later, so make sure to
find it using `blkid` and write it down:

```bash
blkid | grep 'OpenWrt-A'
# ...
#                                                                                 vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
# /dev/sda10: BLOCK_SIZE="262144" TYPE="squashfs" PARTLABEL="OpenWrt-A" PARTUUID="38fe120b-f6d5-4921-888d-1ffa0b1bc370"
```

Now you will need to re-flash the root filesystem to partition 10:

```bash
gunzip -c *-rootfs.img.gz | dd of=/dev/sda10 status=progress
```

After this, you will want to create a filesystem on partition 2 using `mkfs.vfat`.
This will be where you store `openwrt-abpp`.

#### GRUB Changes

Finally, you will need to rename the kernel image and update the GRUB configuration.
The `grub.cfg` file is located on partition 1.

```bash
mkdir -p /mnt/efi
mount -t vfat /dev/sda1 /mnt/efi
mv /mnt/efi/boot/vmlinuz /mnt/efi/boot/vmlinuz-a
nano /mnt/efi/boot/grub/grub.cfg
```

The original GRUB config will like something like this:

```perl
serial --unit=0 --speed=115200 --word=8 --parity=no --stop=1 --rtscts=off
terminal_input console serial; terminal_output console serial

set default="0"
set timeout="5"
search -l kernel -s root

menuentry "OpenWrt" {
        linux /boot/vmlinuz root=PARTUUID=abcdef01-2345-6789-abcd-ef0123456789 rootwait console=ttyS0,115200n8 noinitrd
}

menuentry "OpenWrt (failsafe)" {
        linux /boot/vmlinuz failsafe=true root=PARTUUID=abcdef01-2345-6789-abcd-ef0123456789 rootwait console=ttyS0,115200n8 noinitrd
}
```

>[!tip]
> If your device does not have a serial interface, [you will want to comment out the `serial` and `terminal_input`lines](https://forum.openwrt.org/t/solved-boot-hangs-on-lede-item-in-grub-menu-on-x86-no-grub-timeout/24741/10).

You will need to convert this into a template.

 1. Copy the first non-failsafe `menuentry` to the end of the file.
 2. Prepend a `#` to the beginning of each line of the original `menuentry` blocks.
 3. Surround the original menuentry blocks with:
    
    ```
    ###----- BEGIN ABPP TEMPLATE -----###
    ###----- END ABPP TEMPLATE -----###
    ```

    This will now be the template section.

 4. In the template section:
     * Append `-${LETTER}` after `/boot/vmlinuz`.
     * Append ` ${VERSION}` after `"OpenWrt"`.
     * Replace `root=PARTUUID=...` with `root=${PARTITION}`

 5. Surround the copied menuentry with:
    
    ```
    ###----- BEGIN ABPP GENERATED -----###
    ###----- END ABPP GENERATED -----###
    ```

    This will be the generated section.

 6. In the generated section:
     * Update the `PARTUUID` to the UUID recorded earlier.
     * Append `-a` after `/boot/vmlinuz`.

>[!caution]
> It is **critical** that the section markers have the exact spacing and number of `#` and `-` characters.
>
> The section markers are used to update the GRUB configuration after upgrades, and it will not be possible to do
> automatically unless those exact strings are found in the file.

After you are finished, it should look similar to this:

```perl
# serial --unit=0 --speed=115200 --word=8 --parity=no --stop=1 --rtscts=off
# terminal_input console serial; terminal_output console serial

set default="0"
set timeout="5"
search -l kernel -s root

###----- BEGIN ABPP TEMPLATE -----###
# menuentry "OpenWrt ${VERSION}" {
#         linux /boot/vmlinuz-${LETTER} root=${PARTITION} rootwait console=ttyS0,115200n8 noinitrd
# }
# 
# menuentry "OpenWrt ${VERSION} (failsafe)" {
#         linux /boot/vmlinuz failsafe=true root=${PARTITION} rootwait console=ttyS0,115200n8 noinitrd
# }
###----- END ABPP TEMPLATE -----###

###----- BEGIN ABPP GENERATED -----###
menuentry "OpenWrt" {
        linux /boot/vmlinuz-a root=PARTUUID=38fe120b-f6d5-4921-888d-1ffa0b1bc370 rootwait console=ttyS0,115200n8 noinitrd
}
###----- END ABPP GENERATED -----###
```

You may now reboot into OpenWrt.

### Changes within OpenWrt

Once you have booted into OpenWrt and have internet connectivity, you will need to
install the following packages using `opkg`:

 * `blkid`
 * `block-mount`
 * `dumb-init`
 * `kmod-fs-squashfs`
 * `kmod-fs-vfat`
 * `losetup`
 * `nsenter`
 * `parted`
 * `squashfs-tools-unsquashfs`
 * `unshare`

After installing the packages, configure partition 2
[to be mounted on startup](https://openwrt.org/docs/guide-user/storage/fstab).

Finally, download [a tarball of this repo](https://github.com/eth-p/openwrt-abpp/archive/refs/heads/master.tar.gz) and
extract somewhere within partition 2.

You are now done! 🚀

## Usage

To flash a version of OpenWrt to the inactive partition, run the downloaded `/path/to/openwrt-abpp/bin/abupgrade`
script. It will:

 * Let you select a version to flash.
 * Download the rootfs.
 * Flash the rootfs to the alternate partition.
 * Copy your configuration (using `sysupgrade -b`) to the alternate partition.
 * Download your currently-installed packages to the alternate partition.
 * Update GRUB to automatically select the newly-flashed partition.

Once you reboot into the newly-flashed partition, openwrt-abpp will restore your configuration, install your packages,
and trigger a reboot to finalize everything.

## How it Works

Essentially, it flashes a new OpenWrt installation and copies/downloads your changes to it.

Behind the scenes, it involves:
 * Re-implementing OpenWrt's overlay filesystem initialization code using shell scripts.
 * Creating an extremely lightweight Linux container using `unshare`, `nsenter`, and `dumb-init`.
 * Using the container to run `opkg` within the newly-flashed installation.
