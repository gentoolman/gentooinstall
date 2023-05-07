export MAKEFLAGS="-j16"
export EMERGE_DEFAULT_OPTS="--jobs=16 --load-average=17"

source /etc/profile
export PS1="(chroot) ${PS1}"

# Check if script is being run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

# Select disk device
echo "Please select the disk device to partition:"
lsblk -dplnx size -o name,size | grep -Ev "boot|rpmb|loop" | tac
read -p "Device name: " DISK

mount ${DISK}1 /boot
emerge-webrsync
emerge --sync
eselect news read
eselect profile set default/linux/amd64/17.1/desktop/systemd
time emerge  --verbose --update --deep --newuse @world
time emerge  app-portage/cpuid2cpuflags
echo "*/* $(cpuid2cpuflags)" > /etc/portage/package.use/00cpu-flags
ln -sf ../usr/share/zoneinfo/Europe/Brussels /etc/localtime

echo 'en_US ISO-8859-1
en_US.UTF-8 UTF-8
de_DE ISO-8859-1
de_DE.UTF-8 UTF-8 ' >> /etc/locale.gen
locale-gen
eselect locale set de_DE.utf8

env-update && source /etc/profile && export PS1="(chroot) ${PS1}"

emerge  sys-kernel/linux-firmware sys-kernel/installkernel-gentoo sys-kernel/gentoo-kernel-bin

bash genfstab.sh > /etc/fstab

emerge   net-misc/networkmanager 	sys-fs/e2fsprogs 	sys-fs/dosfstools sudo 


systemd-firstboot --prompt --setup-machine-id
systemctl preset-all --preset-mode=enable-only
systemctl preset-all
systemctl enable  NetworkManager

echo 'GRUB_PLATFORMS="efi-64"' >> /etc/portage/make.conf
emerge  sys-boot/grub
grub-install --target=x86_64-efi --efi-directory=/boot
grub-mkconfig -o /boot/grub/grub.cfg


read -p "Username: " user
useradd -m -G users,wheel,audio,video -s /bin/bash $user
passwd $user
sed --in-place=.bak 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
