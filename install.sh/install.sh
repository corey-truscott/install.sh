#!/bin/bash

NOTIFY="neofetch && neofetch && neofetch"
CHROOT="arch-chroot /mnt"

# set correct time for mirrors
timedatectl set-ntp true

echo -e "make sure all input is correct before entering, or the install will not work\n"
echo -e "this script only supports uefi\n"

# ask if they want to use vim or nano to edit the options file
read -p "do you want to use vim or nano to edit install options? (v/n): " editor

case $editor in
  [vV]* ) EDITOR="vim" ;;
  [nN]* ) EDITOR="nano" ;;
  *) echo "invalid response, try again.\n" && exit ;;
esac


[ $EDITOR == "vim" ] &&
  pacman -Sy --noconfirm vim neofetch

[ $EDITOR == "nano" ] &&
  pacman -Sy --noconfirm nano neofetch

$EDITOR ./opts
source ./opts

lsblk
read -p "which disk would you like to use? (only include the \`sda\` part of the drive name): " main_disk

read -p "press enter to edit drive, information about how to do this is on the arch wiki" _
cfdisk /dev/$main_disk

lsblk
read -p "which drive partition is the home partition? (empty for none): " HOME
read -p "which drive partition is the root partition?: " ROOT
read -p "which drive partition is the boot partition?: " BOOT

mkfs.fat -F32 /dev/$BOOT
mkfs.ext4 /dev/$ROOT

mount /dev/$ROOT /mnt
mkdir -p /mnt/boot
mount /dev/$BOOT /mnt/boot

[ $HOME != "" ] &&
  mkfs.ext4 /dev/$HOME
  mkdir -p /mnt/home
  mount /dev/$HOME /mnt/home

pacstrap -K /mnt $(cat ./pkg)

genfstab -U /mnt >> /mnt/etc/fstab

$CHROOT ln -sf /usr/share/zoneinfo/$ZONEINFO /etc/localtime

$CHROOT hwclock --systohc

$CHROOT echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
$CHROOT echo "en_US ISO-8859-1" >> /etc/locale.gen

$CHROOT locale-gen

$CHROOT echo "LANG=en_US.UTF-8" >> /etc/locale.conf
$CHROOT echo "$KEYMAP" >> /etc/vconsole.conf

$CHROOT echo "$HOSTNAME" >> /etc/hostname

$NOTIFY

echo "Changing root password."
while ! $CHROOT passwd
do
  echo "Try again"
done

$CHROOT systemctl enable NetworkManager.service

$CHROOT grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
$CHROOT grub-mkconfig -o /boot/grub/grub.cfg

echo "rebooting in 5 seconds"
sleep 5
reboot
