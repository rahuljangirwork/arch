#!/bin/bash

# Set mirrors
echo "Server = https://in-mirror.garudalinux.org/archlinux/\$repo/os/\$arch" > /etc/pacman.d/mirrorlist
echo "Server = https://mirror.nag.albony.in/archlinux/\$repo/os/\$arch" >> /etc/pacman.d/mirrorlist
echo "Server = https://in.mirrors.cicku.me/archlinux/\$repo/os/\$arch" >> /etc/pacman.d/mirrorlist

# Set parallel downloads
sed -i 's/#ParallelDownloads = 5/ParallelDownloads = 10/' /etc/pacman.conf

# Set US keyboard
loadkeys us

# Set time according to India
timedatectl set-timezone Asia/Kolkata

# Disk selection
echo "Available disks:"
lsblk
read -p "Enter the disk you want to use (e.g., /dev/sda): " DISK

# Partitioning
parted -s "$DISK" mklabel gpt
parted -s "$DISK" mkpart primary fat32 1 512M
parted -s "$DISK" set 1 esp on
parted -s "$DISK" mkpart primary btrfs 512M 200G

# Formatting
mkfs.fat -F32 "${DISK}1"
mkfs.btrfs "${DISK}2"

# Mounting
mount "${DISK}2" /mnt
mkdir /mnt/boot
mount "${DISK}1" /mnt/boot

# Install base system
pacstrap /mnt base base-devel linux linux-lts linux-firmware linux-lts-headers linux-headers vim nano git terminus-font

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Chroot and configure
arch-chroot /mnt /bin/bash <<EOF

# Set timezone
ln -sf /usr/share/zoneinfo/Asia/Kolkata /etc/localtime
hwclock --systohc

# Set locale
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Set hostname
read -p "Enter hostname: " HOSTNAME
echo "$HOSTNAME" > /etc/hostname

# Set root password
passwd

# Create user
read -p "Enter username: " USERNAME
useradd -m -G wheel -s /bin/bash "$USERNAME"
passwd "$USERNAME"

# Configure sudo
echo "$USERNAME ALL=(ALL:ALL) ALL" >> /etc/sudoers

# Install and configure bootloader
pacman -S --noconfirm grub efibootmgr
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# Install and enable NetworkManager
pacman -S --noconfirm networkmanager
systemctl enable NetworkManager

# Create swapfile
dd if=/dev/zero of=/swapfile bs=1M count=8192 status=progress
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo "/swapfile none swap defaults 0 0" >> /etc/fstab

EOF

echo "Installation complete. You can now reboot into your new system."