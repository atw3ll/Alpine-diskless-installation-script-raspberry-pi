#!/bin/sh

StorageDevice = mmcblk0
# StorageDevice = vdb

Start_config_partition = 409600 
# starts at 200MiB
End_config_partition = 31866880 
# ends at 15GiB

Start_home = 31867904 
# begins roughly at 15GiB
End_home = ""	      
# uses last sector by inputting a newline for automatic selectionA

create_partition() {
   start_sector = $1
   end_sector   = $2
   number       = $3
   device       = $4
   fdisk /dev/$device << EOF
   n
   p
   $num
   $start_sector
   $end_sector
EOF
}

setup_wifi() {
   FileLocation = $1
   SSID         = $2
   Password     = $3
   FileContent  = $(wpa_passphrase $SSID $Password)
   cat << EOF >   $FileLocation
   $FileContent
EOF
}

# Create config/lbu and apk cache partition
create_partition $Start_config_partition $End_config_partition 2 $StorageDevice
# Create home partition
create_partition $Start_home             $End_home             3 $StorageDevice

# Format partitions with ext4
apk add e2fsprogs
mkfs.ext4 -O ^has_journal,^64bit -L LBU    /dev/"$StorageDevice"2
mkfs.ext4 -O ^has_journal,^64bit -L HOME   /dev/"$StorageDevice"3

echo "/dev/disk/by-label/LBU    /media/       ext4 noatime,ro 0 0" >> /etc/fstab
echo "/dev/disk/by-label/HOME   /home/        ext4 noatime,ro 0 0" >> /etc/fstab 
# home directory on first boot does not have data, safe to mount

mount -a

mkdir /media/LBU
mkdir /media/CACHE

echo "Input SSID"
read ssid_chosen

echo "Input SSID Password"
read ssid_password
setup_wifi "/etc/wpa_supplicant/wpa_supplicant.conf" $ssid_chosen $ssid_password 

rc-update add wpa_supplicant boot
rc-update add wpa_cli boot

rc-service wpa_supplicant start

# DO THIS LAST
setup-alpine -f << EOF
# Example answer file for setup-alpine script
# If you don't want to use a certain option, then comment it out

# Use US layout with US variant
# KEYMAPOPTS="us us"
KEYMAPOPTS=us

# Set hostname to 'alpine'
HOSTNAMEOPTS=raspberrpi

# Set device manager to mdev
DEVDOPTS=mdev

# Contents of /etc/network/interfaces
INTERFACESOPTS="auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp

auto wlan0
iface wlan0 inet dhcp
hostname raspberrpi
"

# Search domain of example.com, Google public nameserver
# DNSOPTS="-d example.com 8.8.8.8"

# Set timezone to UTC
#TIMEZONEOPTS="UTC"
TIMEZONEOPTS=none

# set http/ftp proxy
#PROXYOPTS="http://webproxy:8080"
PROXYOPTS=none

# Add first mirror (CDN)
APKREPOSOPTS="-f -c"

# Create admin user
USEROPTS="-a -u -g audio,video,netdev,wheel userman"
USERSSHKEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIF0aTwAzIc/Tz+9w0DPhjnJy+j3/z57XQMOdpEgJ44yN userman@localhost.localdomain"
# USERSSHKEY="https://example.com/juser.keys"

# Install Openssh
SSHDOPTS=openssh
#ROOTSSHKEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOIiHcbg/7ytfLFHUNLRgEAubFz/13SwXBOM/05GNZe4 juser@example.com"
#ROOTSSHKEY="https://example.com/juser.keys"

# Use openntpd
NTPOPTS="openntpd"
# NTPOPTS=none

# Configuring disks manually as part of shell script
DISKOPTS=none

LBUOPTS=LBU 
APKCACHEOPTS="/media/CACHE"
EOF
