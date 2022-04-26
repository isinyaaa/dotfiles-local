#!/bin/bash

# create a user
useradd -mg users -G wheel user
echo "[Unit]
Description=Mount Share at boot
Requires=systemd-networkd.service
After=network-online.target
Wants=network-online.target
[Mount]
What=//10.0.2.4/qemu
Where=/home/user/shared
Options=vers=3.0,x-systemd.automount,_netdev,x-systemd.device-timeout=10,uid=1001,gid=984,credentials=/root/.cifs,soft,rsize=8192,wsize=8192,mfsymlinks,noperm
Type=cifs
TimeoutSec=30
[Install]
WantedBy=multi-user.target" > /etc/systemd/system/home-user-shared.mount

echo "username=user
password=meow" > .cifs

mkdir /home/user/shared
[ -d /etc/samba ] || mkdir /etc/samba
cp smb.conf /etc/samba/smb.conf

{
    echo '%wheel ALL=(ALL) NOPASSWD: ALL'
    echo 'user ALL=(ALL:ALL) NOPASSWD: ALL'
    echo 'Defaults	env_reset,insults,passprompt="[sudo] password for %p: "'
    echo 'Defaults	timestamp_timeout=10,timestamp_type=global'
} >> /etc/sudoers

# setup ssh
mkdir .ssh
cat id_*.pub > .ssh/authorized_keys

mkdir "/etc/systemd/system/serial-getty@.service.d"
echo '[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin root --noclear %I $TERM' >> "/etc/systemd/system/serial-getty@.service.d/override.conf"

runuser -l user -c 'mkdir /home/user/.ssh'
runuser -l user -c 'cat id_*.pub > /home/user/.ssh/authorized_keys'

# fill the fstab
#echo "#shared_folder /home/user/codes 9p trans=virtio 0 0" >> /etc/fstab
echo "//10.0.2.4/qemu         /home/user/shared  cifs    vers=3.0,x-systemd.automount,uid=1001,gid=984,noperm,credentials=/root/.cifs,soft,rsize=8192,wsize=8192,mfsymlinks 0 0" >> /etc/fstab

systemctl enable sshd smb home-user-shared.mount

rm ./*
reboot
