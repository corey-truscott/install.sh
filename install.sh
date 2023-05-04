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

# ask if they want to use vim or nano to edit the options file
read -p "do you want to use vim or nano to edit install options? (v/n): " editor

# set EDITOR variable
case $editor in
  [vV]* ) EDITOR="vim" ;;
  [nN]* ) EDITOR="nano" ;;
  *) echo "invalid response, try again.\n" && exit ;;
esac

# install the appropriate editor
[ $EDITOR == "vim" ] &&
  pacman -Sy --noconfirm vim neofetch

[ $EDITOR == "nano" ] &&
  pacman -Sy --noconfirm nano neofetch

# TODO: convert the options in opts to questions within the script
# and ask if they wish to preserve the old home folder
#
# edit the options file and source it
$EDITOR ./opts
source ./opts

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

# copy pacman.conf > /etc/pacman.conf (live iso)
cp ./pacman.conf /etc/pacman.conf

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
cp ./pacman.conf /mnt/etc/pacman.conf

# link the timezone to /etc/localtime
$CHROOT ln -sf /usr/share/zoneinfo/$ZONEINFO /etc/localtime

# sync the hardware clock
$CHROOT hwclock --systohc

# generate locale
$CHROOT echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
$CHROOT echo "en_US ISO-8859-1" >> /etc/locale.gen

$CHROOT locale-gen

# generate language
$CHROOT echo "LANG=en_US.UTF-8" >> /etc/locale.conf

# generate keymap
$CHROOT echo "$KEYMAP" >> /etc/vconsole.conf

# generate hostname
$CHROOT echo "$HOSTNAME" >> /etc/hostname

neofetch

# set root password
echo "Changing root password."
while ! $CHROOT passwd
do
  echo "Try again"
done

# enable the NetworkManager service
$CHROOT systemctl enable NetworkManager.service

# install grub
$CHROOT grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
$CHROOT grub-mkconfig -o /boot/grub/grub.cfg

# reboot
echo "rebooting in 5 seconds"
sleep 5
reboot
