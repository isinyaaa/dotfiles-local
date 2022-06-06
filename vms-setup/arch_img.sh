#!/usr/bin/env bash

main() {
    if [ "$IS_MAC" = true ]; then
	if [ "$TARGET" = aarch64 ]; then
	    if [ "$BUILD" = true ]; then
		build_aarch64
	    elif [ "$RESIZE" = true ]; then
		resize_aarch64
	    fi
	# elif [[ "$TARGET" =~ x86 ]]; then
	else
	    echo "No rules to make target! Aborting..."
	fi
    else
	if [[ "$TARGET" =~ x86 ]]; then
	    if [ "$BUILD" = true ]; then
		build_x86_64
	    fi
	elif [[ "$TARGET" =~ aarch64 ]]; then
	    if [ "$BUILD" = true ]; then
		build_aarch64
	    elif [ "$RESIZE" = true ]; then
		resize_aarch64
	    fi
	else
	    echo "No rules to make target! Aborting..."
	fi
    fi
}

wait_for_mount() {
    MNT_FOLDER=${1:-mnt}

    for _ in $(seq 100); do
        sleep 1
        mountpoint "$MNT_FOLDER" > /dev/null && break
    done
}

build_x86_64() {
    set -e
    set -x
    (
	cd "$HOME"/vms
	truncate -s "$img_size" "$img_name.img"
	mkfs.ext4 "$img_name.img"

	if test -d mnt; then
	    mkdir mnt
	fi
	sudo mount "$img_name.img" mnt

	wait_for_mount ""

	sudo pacstrap -c mnt base base-devel vim fish git rustup strace gdb openssh cifs-utils samba

	# configure ssh
	sudo cp ~/.ssh/id_*.pub mnt/root/

	# copy bootstrap script
	sudo cp "$HOME"/vms/setup/script-files/start.sh mnt/root/
	sudo cp "$HOME"/vms/setup/script-files/smb.conf mnt/root/

	# remove root passwd
	sudo arch-chroot mnt/ sh -c "echo 'root:xx' | chpasswd"

	sudo umount mnt
    )

    qemu-img convert -O qcow2 "$HOME/vms/"{"$img_name.img","$img_name.qcow2"}
}

build_aarch64() {
    set -e
    set -x
    (
	cd "$HOME"/vms/setup
	if [[ "$RECYCLE" != true || ! -f "$HOME/vms/$img_name.img" ]]; then
	    docker build -t alarm_build:latest .
	    docker ps -a | grep -q alarm && docker rm alarm
	    docker run --name=alarm --privileged -it -v "$HOME"/vms:/images alarm_build ./docker_script.sh "$img_size" "$img_name.img" -d
	else
	    if [[ -f "$HOME/vms/$img_name.qcow2" ]]; then
		rm -f "$HOME/vms/$img_name.qcow2"
	    fi
	fi
	qemu-img convert -O qcow2 "$HOME/vms/"{"$img_name.img","$img_name.qcow2"}
	[ -e UEFI/flash0.img ] || (
	    cd UEFI
	    wget "https://raw.githubusercontent.com/qemu/qemu/master/pc-bios/edk2-aarch64-code.fd.bz2"
	    bzip2 -d edk2-aarch64-code.fd.bz2
	    truncate -s 64M flash0.img
	    truncate -s 64M flash1.img
	    dd if=edk2-aarch64-code.fd of=flash0.img conv=notrunc
	)
	./new_vm.ext "$img_name.qcow2"
    )
}

resize_aarch64() {
    set -e
    set -x
    (
	cd "$HOME"/vms/setup
	if [[ -f "$HOME/vms/$img_name.qcow2" ]]; then
	    qemu-img convert -O raw "$HOME/vms/$img_name."{qcow2,img}
	elif [[ ! -f "$HOME/vms/$img_name.img" ]]; then
	    echo "No target to resize! Aborting..."
	    exit 1
	fi
	docker build -t alarm_build:latest .
	docker ps -a | grep -q alarm && docker rm alarm
	docker run --name=alarm --privileged -it -v "$HOME"/vms:/images alarm_build ./docker_script.sh --resize "$img_size" "$img_name.img" -d
	qemu-img convert -O qcow2 "$HOME/vms/$img_name."{img,qcow2}
    )
}

BUILD=false
RECYCLE=false
RESIZE=false
if [ "$IS_MAC" = true ]; then
    TARGET=aarch64
else
    TARGET=x86
fi
img_name=new_arch
img_size=32G

while [[ "$#" -gt 0 ]]; do
    case "$1" in
	--build)
	    BUILD=true
	    shift
	    ;;
	--recycle)
	    RECYCLE=true
	    shift
	    ;;
	--target)
	    if [[ -z "$2" ]] && [[ "$2" =~ arch || "$2" =~ x ]]; then
		TARGET="$2"
	    fi
	    shift 2
	    ;;
	--resize)
	    RESIZE=true
	    shift
	    ;;
	*)
	    if [[ "$1" =~ \d*[MG] ]]; then
		img_size=$1
	    elif [[ "$1" =~ \S* ]]; then
		img_name=${1%.*}
	    else
		echo "Invalid option: $1"
		exit 22
	    fi
	    shift
	    ;;
    esac
done

main
