#!/bin/bash

# setup keyring
pacman-key --init
pacman-key --populate archlinuxarm

echo 'LANG=en_US.UTF-8' > /etc/locale.conf
sed -i 's,#\(en_US.*\),\1,' /etc/locale.gen
locale-gen

# download packages
sed -i 's,#Parallel.*,ParallelDownloads = 30,' /etc/pacman.conf
pacman -Syu efibootmgr git rustup bc fish base-devel sudo vim openssh samba strace gdb cifs-utils ranger neovim python-pip ccache inetutils rsync --noconfirm

# setup bootloader
uuid=$(blkid /dev/sda2 -s UUID | sed 's,.*="\(.*\)",\1,')
efibootmgr --disk /dev/sda --part 1 --create --label "Arch Linux ARM" --loader /Image --unicode "root=UUID=$uuid rw initrd=/initramfs-linux.img" --verbose

# setup root user
chsh -s "$(which fish)"
mkdir -p /root/.config/fish
echo 'export TERM=xterm-256color' > /root/.config/fish/config.fish

# setup non-root user
useradd -mg users -G wheel user
echo 'user:meow' | chpasswd
chsh -s "$(which fish)" user

# setup paru
runuser -l user -c 'rustup default stable && git clone https://aur.archlinux.org/paru && cd paru && makepkg -fsri --noconfirm && cd .. && rm -rf paru && paru -Fy'

paru -S neovim pass-git-helper

# setup dotfiles
runuser -l user -c 'curl https://raw.githubusercontent.com/oh-my-fish/oh-my-fish/master/bin/install | fish'
runuser -l user -c 'git clone --recursive https://github.com/isinyaaa/dotfiles .dotfiles && cd .dotfiles && ./install'
runuser -l user -c 'git clone --recursive https://github.com/isinyaaa/dotfiles-local .ldotfiles && cd .ldotfiles && git checkout arch && ./install'

runuser -l user -c 'pip install b4'

# setup samba sharing
echo '[Unit]
Description=Mount Share at boot
Requires=systemd-networkd.service
After=network-online.target
Wants=network-online.target

[Mount]
What=//10.0.2.4/qemu
Where=/home/user/shared
Options=vers=3.0,x-systemd.automount,_netdev,x-systemd.device-timeout=10,uid=1001,gid=984,credentials=/root/.cifs,soft,rsize=130048,wsize=130048,mfsymlinks,noperm
Type=cifs
TimeoutSec=30

[Install]
WantedBy=multi-user.target' > /etc/systemd/system/home-user-shared.mount

echo "username=user
password=meow" > .cifs

runuser -l user -c 'mkdir /home/user/shared'
[ -d /etc/samba ] || mkdir /etc/samba
cp smb.conf /etc/samba/smb.conf

# setup ssh
mkdir .ssh
cat id*.pub > .ssh/authorized_keys
sed -i 's/#\(PasswordAuthentication\).*/\1 yes/' /etc/ssh/sshd_config

mkdir "/etc/systemd/system/serial-getty@.service.d"
echo '[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin root --noclear %I $TERM' >> "/etc/systemd/system/serial-getty@.service.d/override.conf"

runuser -l user -c 'mkdir /home/user/.ssh'
runuser -l user -c 'cat id_*.pub > /home/user/.ssh/authorized_keys'

{
    echo '%wheel ALL=(ALL) NOPASSWD: ALL'
    echo 'user ALL=(ALL:ALL) NOPASSWD: ALL'
    echo 'Defaults	env_reset,insults,passprompt="[sudo] password for %p: "'
    echo 'Defaults	timestamp_timeout=10,timestamp_type=global'
} >> /etc/sudoers

# fill the fstab
#echo "#shared_folder /home/user/codes 9p trans=virtio 0 0" >> /etc/fstab
echo "//10.0.2.4/qemu         /home/user/shared  cifs    vers=3.0,x-systemd.automount,uid=1001,gid=984,noperm,credentials=/root/.cifs,soft,rsize=130048,wsize=130048,mfsymlinks 0 0" >> /etc/fstab

systemctl enable sshd smb home-user-shared.mount

rm ./*
