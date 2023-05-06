#!/bin/bash

# declaring the chroot command
CHROOT="arch-chroot /mnt"

# set correct time for mirrors
timedatectl set-ntp true

echo -e "warning: as of now, the home folder is formatted, if you wish to disable this, as of now you will need to find the line"
echo -e "         \`mkfs.ext4 /dev/$HOME\`, and delete it."

# putting disclaimers on the script about its usability 
echo -e "make sure all input is correct before entering, or the install will not work\n"
echo -e "this script only supports uefi\n"

read -p "what do you want your hostname to be?: " hostname

# TODO: implement approximating timezone
read -p "what is your timezone? (example: Europe/London): " zoneinfo

# TODO: implement "us" as the default if left blank
read -p "what is your keymap? (example: us): " keymap

# ask the user for username
read -p "what do you want your username to be?: " username

# ask which drive to use
lsblk
read -p "which disk would you like to use? (only include the \`sda\` part of the drive name): " main_disk

# ask the user to format the drive accordingly to their own preferences/size of drive/etc
read -p "press enter to edit drive, information about how to do this is on the arch wiki" _
cfdisk /dev/$main_disk

# ask which partition is for which directory
lsblk
read -p "which drive partition is the home partition? (empty for none): " HOME
read -p "which drive partition is the root partition?: " ROOT
read -p "which drive partition is the boot partition?: " BOOT

# install neofetch to notify the user later
pacman -Sy --noconfirm neofetch

# copy pacman.conf > /etc/pacman.conf (live iso)
cat ./pacman > /etc/pacman.conf

# format boot and root partitions
mkfs.fat -F32 /dev/$BOOT
mkfs.ext4 /dev/$ROOT

# mount root
mount /dev/$ROOT /mnt

# mount boot
mkdir -p /mnt/boot
mount /dev/$BOOT /mnt/boot

# if home != empty, format and mount it
[ $HOME = "" ] ||
  mkfs.ext4 /dev/$HOME
  mkdir -p /mnt/home
  mount /dev/$HOME /mnt/home

# pacstrap the required packages
pacstrap -K /mnt $(cat ./pkg)

# generate the fstab file
genfstab -U /mnt >> /mnt/etc/fstab

# copy pacman.conf to the live machine
cat ./pacman > /mnt/etc/pacman.conf

# link the timezone to /etc/localtime
$CHROOT ln -sf /usr/share/zoneinfo/$zoneinfo /etc/localtime

# sync the hardware clock
$CHROOT hwclock --systohc

# generate locale
$CHROOT echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
$CHROOT echo "en_US ISO-8859-1" >> /etc/locale.gen

$CHROOT locale-gen

# generate language
$CHROOT echo "LANG=en_US.UTF-8" >> /etc/locale.conf

# generate keymap
$CHROOT echo "$keymap" >> /etc/vconsole.conf

# generate hostname
$CHROOT echo "$hostname" >> /etc/hostname

# enable the NetworkManager service
$CHROOT systemctl enable NetworkManager.service

# install grub
$CHROOT grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
$CHROOT grub-mkconfig -o /boot/grub/grub.cfg

# notify
neofetch

# set root password
echo "Changing root password."
while ! $CHROOT passwd
do
  echo "Try again"
done

# HYPR INSTALL

$CHROOT useradd -m $username
$CHROOT usermod -aG wheel $username

# notify
neofetch

# set user password
echo "Changing $username password."
while ! $CHROOT passwd
do
  echo "Try again"
done

su - $username -c "touch a"

$CHROOT sed -i 's/^# %wheel ALL=(ALL) NOPASSWD: ALL/%wheel ALL=(ALL) NOPASSWD: ALL/' /etc/sudoers
$CHROOT sed -i 's/^# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers

$CHROOT su - $username -c git clone https://aur.archlinux.org/yay.git ~/home/$username
$CHROOT cd /home/$username/yay && su - $username -c makepkg -sri

$CHROOT yay -S --noconfirm --needed --removemake $(cat ./aur)
# readd mullvad-vpn-cli 

$CHROOT rm -rf /home/$username/*
$CHROOT git clone https://github.com/corey-truscott/hypr_dotfiles.git ~/home/$username
$CHROOT chown -R $username: /home/$username

# reboot
echo "rebooting in 5 seconds"
sleep 5
reboot
