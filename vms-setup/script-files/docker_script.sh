#!/bin/bash

RESIZE=0

main() {
    set -e
    set -x

    if [[ "$1" = --resize ]]; then
	RESIZE=1
	shift
    fi
    disk_size=$1
    disk_name=$2
    mountpoint /mnt && umount -R /mnt
    ls "*.img" && {
	kpartx -d "*.img"
	rm -rf "*.img"
    }

    if [[ "$RESIZE" = 0 ]]; then
	truncate -s "$disk_size" "$disk_name"
	gdisk "$disk_name" << EOF
o
Y
n


+256M
ef00
n




w
Y
EOF
	kpartx -av "$disk_name"
    else
	kpartx -av "images/$disk_name"
    fi
    loopdev="$(losetup -a | grep "/$disk_name" |\
	sed 's,/dev/\(.*\): .*,\1,' |\
	sort -t p -k 2n -n | tail -n1)"
    efivol=/dev/mapper/"$loopdev"p1
    rootvol=/dev/mapper/"$loopdev"p2
    if [[ "$RESIZE" = 0 ]]; then
	mkfs.vfat "$efivol"
	echo "Y" | mkfs.ext4 "$rootvol"
	mount "$rootvol" /mnt
	mkdir /mnt/boot
	mount "$efivol" /mnt/boot
	bsdtar -xpf ArchLinuxARM-aarch64-latest.tar.gz -C /mnt
	cp start_aarch64.sh /mnt/root/
	cp smb.conf /mnt/root/
	cp id*.pub /mnt/root/
	exp='s,.*="\(.*\)",\1,'
	efiuuid="$(blkid "$efivol" -s UUID | sed "$exp")"
	rootuuid="$(blkid "$rootvol" -s UUID | sed "$exp")"
	echo "
    UUID=$efiuuid	/boot	vfat	defaults	0 0
    UUID=$rootuuid	/	ext4	defaults	0 0" > /mnt/etc/fstab
	echo "Image root=UUID=$rootuuid rw initrd=\\initramfs-linux.img" \
	    > /mnt/boot/startup.nsh

	umount /mnt/boot
	umount /mnt
    fi
    e2fsck -f "$rootvol"
    resize2fs "$rootvol"
    kpartx -d "$disk_name"
    sync
    if [[ "$RESIZE" = 0 ]]; then
	mv "$disk_name" images/
    fi
}

main "$@"
