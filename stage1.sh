#!/bin/bash

# Define variables
STAGE3_URL="http://mirror.eu.oneandone.net/linux/distributions/gentoo/gentoo/releases/amd64/autobuilds/current-livegui-amd64/stage3-amd64-desktop-systemd-20230423T164653Z.tar.xz"

# Check if script is being run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

# Select disk device
echo "Please select the disk device to partition:"
lsblk -dplnx size -o name,size | grep -Ev "boot|rpmb|loop" | tac
read -p "Device name: " DISK

# Create partition table
parted -s $DISK mklabel gpt
parted -s $DISK mkpart efi fat32 1MiB 1GB
parted -s $DISK set 1 esp on
parted -s $DISK mkpart swap linux-swap 1GB 17GB
parted -s $DISK mkpart root ext4 17GB 100%

# Format partitions
mkfs.vfat -F 32 ${DISK}1
mkswap ${DISK}2
mkfs.ext4 ${DISK}3

# Make the needed directory and mount the partitions
mkdir -p /mnt/gentoo
mount ${DISK}3 /mnt/gentoo

# Enable swap
swapon ${DISK}2

# set automatic timezone config and get stage 3
ntpd -q -g
cd /mnt/gentoo
wget $STAGE3_URL
tar xpvf stage3-*.tar.xz --xattrs-include='*.*' --numeric-owner
cd /mnt/gentoo

# configure make.conf for desktop USE flags
sed --in-place=.bak 's/^COMMON_FLAGS="-O2 -pipe"/COMMON_FLAGS="-march=native -O2 -pipe"/' /mnt/gentoo/etc/portage/make.conf
echo 'USE=" * X a52 aac acl acpi alsa amd64 bluetooth branding bzip2 cairo cdda cdr cli crypt cups dbus dri dts dvd dvdr encode exif flac fortran gdbm gif gpm gtk gui iconv icu ipv6 jpeg lcms libglvnd libnotify libtirpc mad mng mp3 mp4 mpeg multilib ncurses nls nptl ogg opengl openmp pam pango pcre pdf png policykit ppds qt5 readline sdl seccomp sound spell split-usr ssl startup-notification svg systemd test-rust tiff truetype udev udisks unicode upower usb vorbis wxwidgets x264 xattr xcb xft xml xv xvid zlib "' >> /mnt/gentoo/etc/portage/make.conf
echo 'MAKEOPTS="-j16"' >> /mnt/gentoo/etc/portage/make.conf
echo 'ACCEPT_LICENSE=" * "' >> /mnt/gentoo/etc/portage/make.conf


mirrorselect -s7 -D -o >> /mnt/gentoo/etc/portage/make.conf

# dns mount and chroot
mkdir --parents /mnt/gentoo/etc/portage/repos.conf
cp /mnt/gentoo/usr/share/portage/config/repos.conf /mnt/gentoo/etc/portage/repos.conf/gentoo.conf
cp --dereference /etc/resolv.conf /mnt/gentoo/etc/

mount --types proc /proc /mnt/gentoo/proc
mount --rbind /sys /mnt/gentoo/sys
mount --make-rslave /mnt/gentoo/sys
mount --rbind /dev /mnt/gentoo/dev
mount --make-rslave /mnt/gentoo/dev
mount --bind /run /mnt/gentoo/run
mount --make-slave /mnt/gentoo/run

test -L /dev/shm && rm /dev/shm && mkdir /dev/shm
mount --types tmpfs --options nosuid,nodev,noexec shm /dev/shm
chmod 1777 /dev/shm /run/shm
chroot /mnt/gentoo /bin/bash

