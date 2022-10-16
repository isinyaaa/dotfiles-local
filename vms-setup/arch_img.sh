#!/usr/bin/env bash

main() {
    if [ "$IS_MAC" = true ]; then
	if [ "$TARGET" = aarch64 ]; then
	    if [ "$BUILD" = true ]; then
		build_aarch64
	    elif [ "$RESIZE" = true ]; then
		resize_aarch64
	    elif [ "$RUN" = true ]; then
		run_aarch64
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
	if [[ -f "$HOME/vms/$img_name.qcow2" ]]; then
	    rm -f "$HOME/vms/$img_name.qcow2"
	fi
	if [[ "$RECYCLE" == false || ! -f "$HOME/vms/$img_name.img" ]]; then
	    docker build -t alarm_build:latest .
	    docker ps -a | grep -q alarm && docker rm alarm
	    docker run --name=alarm --privileged --rm -it -v "$HOME"/vms:/images alarm_build ./docker_script.sh "$img_size" "$img_name.img"
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
	./new_vm.ext "$img_name"
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
	docker run --name=alarm --privileged --rm -it -v "$HOME"/vms:/images alarm_build ./docker_script.sh --resize "$img_size" "$img_name.img" -d
	qemu-img convert -O qcow2 "$HOME/vms/$img_name."{img,qcow2}
    )
}

run_aarch64() {
    mem_amount=4G
    if [ "$IS_MAC" = true ]; then
        cpuvar=host
        accelvar=",accel=hvf"
    else
        cpuvar="cortex-a72"
    fi

    eval qemu-system-aarch64 -L ~/bin/qemu/share/qemu \
         -smp 8 \
         -machine virt"$accelvar" \
         -cpu "$cpuvar" -m "$mem_amount" \
         "-drive if=pflash,media=disk,file=$HOME/vms/setup/UEFI/flash"{"0.img,id=drive0","1.img,id=drive1"}",cache=writethrough,format=raw" \
         -drive if=none,file="$HOME/vms/$img_name.qcow2",format=qcow2,id=hd0 \
         -device virtio-scsi-pci,id=scsi0 \
         -device scsi-hd,bus=scsi0.0,drive=hd0,bootindex=1 \
         -nic user,model=virtio-net-pci,hostfwd=tcp::2222-:22,smb="$HOME"/shared \
         '-device virtio-'{rng,balloon,keyboard,mouse,serial,tablet}-device \
         -object cryptodev-backend-builtin,id=cryptodev0 \
         -device virtio-crypto-pci,id=crypto0,cryptodev=cryptodev0 \
         -nographic

}

BUILD=false
RECYCLE=false
RESIZE=false
RUN=false
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
	--run)
	    RUN=true
	    shift
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
