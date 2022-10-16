#!/bin/bash

prepare() {
    if test mountpoint /mnt; then
	umount -R /mnt
    fi
    if test ls /.*img; then
	for i in /*.img; do
	    if [[ "$i" =~ control ]]; then
		continue
	    fi
	    kpartx -d "$i"
	    rm -rf "/*.img"
	done
    fi
    nloopdevn=$(losetup -f | tr -dc '0-9')
    nloopdevn=$((nloopdevn - 1))
    for i in $(seq $nloopdevn); do
	kpartx -d "/dev/loop$i"
    done
}

partition() {
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
}

main() {
    set -ex

    disk_size=$1
    disk_name=$2

    prepare

    if [[ -z "$PREFIX" ]]; then
	partition
    fi

    # create loop devices
    kpartx -av "$PREFIX/$disk_name"
    loopdev="$(losetup -a | grep "$PREFIX/$disk_name" |\
	sed 's,/dev/\(.*\): .*,\1,' |\
	sort -t p -k 2n -n | tail -n1)"
    efivol=/dev/mapper/"$loopdev"p1
    rootvol=/dev/mapper/"$loopdev"p2

    # prepare partitions
    if [[ "$RESIZE" = 0 ]]; then
	if [[ "$RECOVER" = 0 ]]; then
	    # create filesystems
	    mkfs.vfat "$efivol"
	    echo "Y" | mkfs.ext4 "$rootvol"
	    mount "$rootvol" /mnt
	    mkdir /mnt/boot
	    mount "$efivol" /mnt/boot
	    bsdtar -xpf ArchLinuxARM-aarch64-latest.tar.gz -C /mnt
	    cp start_aarch64.sh /mnt/root/
	    cp smb.conf /mnt/root/
	    cp id*.pub /mnt/root/
	else
	    mount "$rootvol" /mnt
	    mount "$efivol" /mnt/boot
	    mount -o bind /dev /mnt/dev
	    chroot /mnt mount none -t proc /proc
	    chroot /mnt mount none -t sysfs /sys
	    chroot /mnt mount none -t devpts /dev/pts
	    chroot /mnt mkinitcpio -P
	fi
	# prepare for boot
	exp='s,.*="\(.*\)",\1,'
	efiuuid="$(blkid "$efivol" -s UUID | sed "$exp")"
	rootuuid="$(blkid "$rootvol" -s UUID | sed "$exp")"
	echo "\
UUID=$efiuuid	/boot	vfat	defaults	0 0
UUID=$rootuuid	/	ext4	defaults	0 0" > /mnt/etc/fstab
	echo "Image root=UUID=$rootuuid rw initrd=\\initramfs-linux.img" \
	    > /mnt/boot/startup.nsh

	umount -R /mnt
    fi

    # check partition sizes or resize
    e2fsck -f "$rootvol"
    resize2fs "$rootvol"

    # remove loop devices
    kpartx -d "/dev/$loopdev"
    sync

    # move to shared volume
    if [[ -z "$PREFIX" ]]; then
	mv "$disk_name" images/
    fi
}

PREFIX=''
RECOVER=0
RESIZE=0

while [[ $# -gt 0 ]]; do
    case "$1" in
	--recover)
	    RECOVER=1
	    PREFIX='/images'
	    shift
	    ;;
	--resize)
	    RESIZE=1
	    PREFIX='/images'
	    shift
	    ;;
	*)
	    break
	    ;;
    esac
done
if [[ "$RESIZE" = 1 && "$RECOVER" = 1 ]]; then
    echo 'Cannot resize and recover at the same time'
    exit 1
fi
main "$@"
