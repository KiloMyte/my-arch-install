# 🐧 my-arch-install

Shell script designed to streamline and automate the installation process for Arch Linux.

## ❓ Who should use this?

This script is tailored for users who:

- are familiar with Arch Linux and want to automate the installation process.
- want a somewhat clean installation of Arch Linux.
- do not need to dual boot.

## ❗ What this script does

- Will wipe your selected drive and install Arch Linux into it. Dual Booting is not supported in this script.
- Creates 2 partitions: `root` and `boot`.
- Uses `btrfs` as the filesystem and creates 5 subvolumes: `@`, `@.snapshots`, `@home`, `@log`, `@cache`, and `@swap`.
- Uses LUKS on a partition as encryption.
- Mounts the `boot` partition into `/mnt/boot`.
- Creates a 16GB swapfile.
- Symlinks `dash` to `/bin/sh`.
- Uses `PipeWire` for audio.
- Uses `systemd-boot` as the bootloader.
- Uses `Wayland` as the display server protocol with `Hyprland` as the compositor.

## 🚀 Installation

After booting into the Arch Linux Live ISO and connected to the internet, run the following commands:

```sh
timedatectl set-ntp true
pacman -Sy git
git clone https://github.com/KiloMyte/my-arch-install.git
cd my-arch-install
chmod +x pre.sh
./pre-sh
```
