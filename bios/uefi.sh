#!/bin/bash

# color
WHITE="$(tput setaf 7)"
RED="$(tput setaf 1)"
RESET="$(tput sgr0)"
BLINK="$(tput blink)"
GREEN="$(tput setaf 2)"

# version 
version='0.2'

# packages base
base='base base-devel linux linux-firmware sudo networkmanager bluez bluez-utils grub efibootmgr os-prober wpa_supplicant amd-ucode intel-ucode'

chroot='/mnt'

disk='/dev/sda'

null='/dev/null'

editor='vim nano'

ctrlc_trap()
{
	echo
	err "ctrl + C detected, Exiting ..."
	exit 0
}

trap ctrlc_trap 2

checking_internet()
{
	if ping -q -c 1 -W 1 8.8.8.8 >/dev/null; then
		return 0
	else
		err "You are offline, please check you internet ..."
		exit 0
	fi
}

err() {
	printf "%s=> %s%s\n" "$RED" "$RESET" "$@"
}

msg_procces() {
	printf "%s* %s%s\n" "$GREEN" "$RESET" "$@" 
}

msg_ask () {
	printf "[?] %s\n" "$@"
}

title() {
	printf "%s>> %s%s\n" "$GREEN" "$RESET" "$@"
}

banner ()
{
	echo "
<===== Welcome to Ice Linux installer! =====>
=> version : $version
=> author  : NekoIceCream
=> git 	   : https://github.com/NekoIceTeam/IceLinux-Installer
=> Revision From
=> author  : Rey Fooster
=> git 	   : https://github.com/fooster1337/arch-installer
<============ I Use Arch Btw ===========>
"
}

partition() {
	title "Set up you partition"
	echo
	read -p "[+] create a partition for arch? [${GREEN}Yes${RESET}/${RED}No${RESET}] " set 
	case "$set" in
		y|Yes|Y|yes|YES)
		cfdisk $disk
		return
		;;
		n|No|N|no|NO)
		return
		;;
		*)
		return
		;;
esac
} 
set_partition() {
	echo
	title "Choose you partition"
	echo
	fdisk -l $disk -o device,size,type | \
    grep "$disk[[:alnum:]]" |awk '{print $1;}'
    echo
	read -p "[?] Filesystem partition : " filesystem
	read -p "[?] Type filesystem [ext2,ext3,ext4,btrfs] : " type
	read -p "[?] Boot partition : " boot
	read -p "[?] Swap partition : " swap
	echo "
${GREEN}
$filesystem => $type
$boot => efi partition
$swap => swap
${RESET}
"
	read -p "[?] this will format the selected partition, sure you don't regret it? [${GREEN}Yes${RESET}/${RED}No${RESET}] " select
	case "$select" in
		y|Yes|Y|yes|YES)
		return
		;;
		n|No|N|no|NO)
		set_partition
		;;
		*)
		return
		;;
esac		
}
format_partition() {
	echo
	title "Formatting partition"
	echo
	msg_procces "Creating $type partition ..."
	mkfs.$type -F $filesystem > $null 2>&1
	sleep 1
	msg_procces "Creating boot partition ..."
	mkfs.fat -F32 $boot > $null 2>&1
	sleep 1
	msg_procces "Creating SWAP partition ..."
	mkswap $swap > $null 2>&1
	return
}
mount_partition ()
{
	echo 
	title "Mounting partition"
	echo
	msg_procces "mounting filesystem ..."
	mount $filesystem $chroot
	sleep 1
	msg_procces "mount boot partition ..."
	mkdir -p $chroot/boot/efi
	mount $boot $chroot/boot/efi
	sleep 1
	msg_procces "Activating swap ..."
	swapon $swap
	sleep 1
	return
}
install_base ()
{
	echo
	title "Install base system for arch"
	echo
	msg_procces "Installing packages, make sure the internet is still active ..."
	pacman -Sy --noconfirm > $null 2>&1
	pacstrap $chroot $base $editor $browser > $null 2>&1
	genfstab -U $chroot >> $chroot/etc/fstab
	msg_procces "Finished ..."
	sleep 2
	return
}

set_timezone () 
{
	echo 
	title "configuration"
	echo
	read -p "[?] Set timezone (Region/City) : " timezone
	msg_procces "Set timezone $timezone ..."
	msg_procces "Success ..."
	arch-chroot $chroot ln -sf /usr/share/zoneinfo/$timezone /etc/localtime 
	arch-chroot $chroot hwclock --systohc
	return
}

set_hostname () 
{
	echo 
	title "Set hostname"
	echo
	read -p "[?] You hostname : " hostname
	echo
	msg_procces "Set hostname $hostname ..."
	sleep 2
	cat > $chroot/etc/hostname <<EOF
$hostname
EOF
	cat > $chroot/etc/hosts <<EOF
127.0.0.1	localhost
::1 		localhost
127.0.1.1 	$hostname.localdomain	$hostname
EOF
	msg_procces "Success ..."

return
}

set_username() 
{
	echo
	title "Set non-root user"
	echo
	read -p "[?] You username : " username
	echo
	msg_procces "Set username $username ..."
	sleep 2
	arch-chroot $chroot useradd -mG wheel $username
	msg_procces "Success ..."
	return
}

set_password () 
{
	echo
	title "Set password"
	echo 
	msg_procces "Set password for root ..."
	arch-chroot $chroot passwd
	echo
	msg_procces "Set password for $username ..."
	arch-chroot $chroot passwd $username
	echo
	msg_ask "set password success ..."
	sleep 1
	return
}

locale() {
	echo
	title "Set locale"
	echo
	read -p "[?] Set locale [en_US.UTF-8 UTF-8] : " locale
	case "$locale" in
		*)
		echo "en_US.UTF-8 UTF-8" >> $chroot/etc/locale.gen
		arch-chroot $chroot locale-gen > $null 2>&1
	esac
}

set_locale () {
	echo
	msg_procces "set locale ..."
	echo $locale >> $chroot/etc/locale-gen
	arch-chroot $chroot locale-gen > $null 2>&1
	msg_procces "Success ..."
	return
}

install_grub () {
	echo
	title "Installing grub"
	echo
	msg_procces "Install GRUB ..."
	arch-chroot $chroot grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ARCH_GRUB > $null 2>&1
	arch-chroot $chroot grub-mkconfig -o /boot/grub/grub.cfg > $null 2>&1
	msg_procces "Install GRUB success ..."
	sleep 2
	return
}

}
finish_install () {
	echo
	title "Finish install"
	echo 
	msg_procces "Enabled services ..."
	arch-chroot $chroot systemctl enable NetworkManager > $null 2>&1
	arch-chroot $chroot systemctl enable bluetoothd > $null 2>&1
	sleep 1
	echo
	msg_procces "umount filesystem ..."
	umount -R $chroot > $null 2>&1
	umount -l $chroot > $null 2>&1
	sleep 2
	echo
	echo "[+] Installing arch success! ..."
	echo 
	echo "      /\
     /  \
    /\   \
   /      \ I use arch btw
  /   ,,   \
 /   |  |  -\
/_-''    ''-_\ "
    echo
	echo "Now you can say ${blink}I use arch btw ..."
	echo
	return
}


reboot () {
	echo
	title "Rebooting System"
    umount -a
	sleep 2
	reboot
}

main(){
	checking_internet
	banner
	partition
	set_partition
	format_partition
	mount_partition
	install_base
	set_timezone
	set_hostname
	set_username
	set_password
	locale
	set_locale
	install_grub
	finish_install
    reboot
}

main "$@"
