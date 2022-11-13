#!/usr/bin/env bash

VM_PATH="$HOME/vms"
MNT_FOLDER="$VM_PATH/mnt"

create-vm() {
    set -x

    NEW_FILE=true

    if [[ -e "$img_name.raw" && "$OVERWRITE" = false ]]; then
        NEW_FILE=false
    fi
    [ "$NEW_FILE" = true ] && {
        truncate -s "$img_size" "$img_name.raw" \
            || return 1
        mkfs.ext4 "$img_name.raw" \
            || return 1
    }

    test -d "$MNT_FOLDER" || mkdir "$MNT_FOLDER"
    sudo mount "$img_name.raw" "$MNT_FOLDER" || return 1

    for i in $(seq 100); do
        sleep 1
        mountpoint "$MNT_FOLDER" > /dev/null && break
    done

    sudo pacstrap -c "$MNT_FOLDER" base base-devel dhcpcd || {
        sudo umount "$MNT_FOLDER"
        return 1
    }

    # configure ssh
    sudo cp ~/.ssh/id_rsa.pub "$MNT_FOLDER/root/" || {
        sudo umount "$MNT_FOLDER"
        return 1
    }

    # copy bootstrap script
    (
        sudo cp "$VM_PATH/setup/script-files/start_x86.sh" "$MNT_FOLDER/root/" && \
            sudo cp "$VM_PATH/setup/script-files/smb.conf" "$MNT_FOLDER/root/"
    ) || {
        sudo umount "$MNT_FOLDER"
        return 1
    }

    # remove root passwd
    sudo arch-chroot "$MNT_FOLDER" sh -c "echo 'root:xx' | chpasswd"

    sudo umount "$MNT_FOLDER"

    qemu-img convert -O qcow2 "$img_name.raw" "$img_name.qcow2" ||
        return 1
}

img_size=8G
img_name="$VM_PATH/arch"
OVERWRITE=false

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --overwrite)
            OVERWRITE=true
            ;;
        *)
            if [[ "$1" =~ \d*[MG] ]]; then
                img_size="$1"
            elif [[ "$1" =~ \S* ]]; then
                img_name="${VM_PATH}/${1}"
            else
                echo "Invalid argument: $1"
                exit 22
            fi
            ;;
    esac
    shift
done

create-vm $@
