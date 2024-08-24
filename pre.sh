#!/bin/sh

# Pre-Install script

# formatting
error() {
	printf "[\033[1;31mERROR\033[0m] %s\n" "$1"
}

input() {
	printf "[\033[1;34mINPUT\033[0m] %s" "$1"
}

newline() {
	printf "\n"
}

success() {
	printf "[\033[1;32mSUCCESS\033[0m] %s\n" "$1"
}

# get hostname
while true; do
	input "Enter desired hostname: " && read -r hsn
	if printf "%s" "$hsn" | grep -q "^[a-z][a-z0-9-]*$"; then
		success "Hostname will be set to: $hsn"
		newline
		break
	else
		error "Invalid hostname. Try again."
	fi
done

# get root password
stty -echo
while true; do
	input "Enter password for root: " && read -r rpass1
	newline
	input "Re-enter password: " && read -r rpass2
	newline
	if [ "$rpass1" = "$rpass2" ]; then
		success "Root password has been set."
		newline
		break
	else
		error "Passwords do not match. Try again."
	fi
done
stty echo

# get username
while true; do
	input "Enter desired username: " && read -r usn
	if printf "%s" "$usn" | grep -q "^[a-z][a-z0-9-]*$"; then
		success "Username will be: $usn"
		newline
		break
	else
		error "Invalid username. Try again."
	fi
done

# get user password
stty -echo
while true; do
	input "Enter password for $usn: " && read -r upass1
	newline
	input "Re-enter password: " && read -r upass2
	newline
	if [ "$upass1" = "$upass2" ]; then
		success "Password for $usn has been set."
		newline
		break
	else
		error "Passwords do not match. Try again."
	fi
done
stty echo

# get drive to format
while true; do
	lsblk
	input "Enter drive to format (Ex. \"sda\" OR \"nvme0n1\"): " && read -r dr
	if lsblk | grep -qw "$dr"; then
		success "Drive /dev/$dr exists."
		newline
		case "$dr" in
			*nvme*) bp=/dev/"$dr"p1 && rp=/dev/"$dr"p2 ;;
			*) bp=/dev/"$dr"1 && rp=/dev/"$dr"2 ;;
		esac
		break
	else
		error "Drive /dev/$dr doesn't exist. Please enter a valid drive."
	fi
done

# prompt for ParallelDownloads
while true; do
	input "Do you want to enable ParallelDownloads for pacman? [y/n] " && read -r ans
	case "$ans" in
		[yY]) input "Enter desired number for ParallelDownloads: " && read -r num
			[ "$num" -eq "$num" ] 2>/dev/null || { error "Invalid input. Please enter a valid integer."; newline; continue;}
			sed -i "s/^#ParallelDownloads = 5$/ParallelDownloads = $num/" /etc/pacman.conf
			success "ParallelDownloads has been enabled with $num downloads."
			newline
			break ;;
		[nN]) success "ParallelDownloads will not be enabled."
			break ;;
		*) error "Invalid input. Please enter \"y\" or \"n\"."
	esac
done

# update mirrorlist
printf "Updating mirrorlist with reflector. Please wait...\n"
reflector --latest 10 --sort rate --save /etc/pacman.d/mirrorlist --protocol https --download-timeout 20

# sync mirrors and install keyring
pacman -Syy --noconfirm archlinux-keyring

# format disk
sgdisk -Z /dev/"$dr"
sgdisk -a 2048 -o /dev/"$dr"

# create partitions
sgdisk -n 1::1G --typecode=1:ef00 /dev/"$dr"
sgdisk -n 2::-0 --typecode=2:8300 /dev/"$dr"

# encrypt and format root partition, and format boot partition
cryptsetup -c aes-xts-plain64 -h sha512 --use-urandom -y -v luksFormat "$rp"
cryptsetup luksOpen "$rp" crypt-root
mkfs.btrfs /dev/mapper/crypt-root
mkfs.vfat "$bp"

# mount root and boot partition
mount /dev/mapper/crypt-root /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@.snapshots
btrfs subvolume create /mnt/@cache
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@log
btrfs subvolume create /mnt/@swap
umount /mnt
mount -o rw,relatime,ssd,discard=async,space_cache=v2,compress=zstd,subvol=/@ /dev/mapper/crypt-root /mnt
mkdir -p /mnt/.snapshots /mnt/home /mnt/var/log /mnt/var/cache /mnt/boot /mnt/swap
mount -o rw,relatime,ssd,discard=async,space_cache=v2,compress=zstd,subvol=/@.snapshots /dev/mapper/crypt-root /mnt/.snapshots
mount -o rw,relatime,ssd,discard=async,space_cache=v2,compress=zstd,subvol=/@cache /dev/mapper/crypt-root /mnt/var/cache
mount -o rw,relatime,ssd,discard=async,space_cache=v2,compress=zstd,subvol=/@home /dev/mapper/crypt-root /mnt/home
mount -o rw,relatime,ssd,discard=async,space_cache=v2,compress=zstd,subvol=/@log /dev/mapper/crypt-root /mnt/var/log
mount -o rw,relatime,ssd,discard=async,space_cache=v2,compress=zstd,subvol=/@swap /dev/mapper/crypt-root /mnt/swap
mount "$bp" /mnt/boot

# determine if processor is AMD or Intel for microcode package
cpu=$(grep vendor_id /proc/cpuinfo)
case "$cpu" in
	*AuthenticAMD) microcode=amd-ucode ;;
	*GenuineIntel) microcode=intel-ucode ;;
esac

# install essential packages
pacstrap -K /mnt base linux linux-firmware btrfs-progs "$microcode"

# create swapfile
btrfs filesystem mkswapfile --size 16g --uuid clear /mnt/swap/swapfile
swapon /mnt/swap/swapfile

# reload partition table and generate fstab file
partprobe /dev/"$dr"
genfstab -U /mnt >> /mnt/etc/fstab

# copy current mirrorlist and pacman.conf to mounted root
cp /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist
cp /etc/pacman.conf /mnt/etc/pacman.conf

# add variables
{
	printf "hsn=%s\n" "$hsn"
	printf "rpass=%s\n" "$rpass1"
	printf "usn=%s\n" "$usn"
	printf "upass=%s\n" "$upass1"
	printf "microcode=%s\n" "$microcode"
	printf "root_uuid="
	blkid -s UUID -o value "$rp"
	printf "\ncrypt_uuid="
	blkid -s UUID -o value /dev/mapper/crypt-root
} > vars

# copy vars to source for variables to be used in Base Installation
cp vars /mnt/vars

# copy base and post install script to /mnt and make "base.sh" executable
cp base.sh /mnt/base.sh
cp post.sh /mnt/post.sh
chmod +x base.sh

# Pre-Install done
clear
printf "Pre-Installation done! Performing Base installation now...\n"
sleep 3
arch-chroot /mnt ./base.sh
