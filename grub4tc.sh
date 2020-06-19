#!/bin/sh
# 
# The purpose of this script is to make BIOS/UEFI bootable removable drive.
# Version 0.1 (c) 2020 Andrey Dobrovolsky

if [ "$1" == "-h" -o "$1" == "--help" ]
then

#--------------------------
# Usage & short description
#--------------------------

  cat << EOF

Makes removable drive BIOS/UEFI dual-bootable, intended for use with multiple
TinyCore Linux versions, bitnesses, flavors and user presets.

Usage:

    grub4tc.sh [ <drive name> | wait ] [ <boot partition size in MB> ]

    If <drive name> ommitted or set to "wait", detects first removable drive,
connected after the script was started. /dev/sda, drive being used by TinyCore
for /etc/sysconfig/tcedir, drives with mounted partitions are rejected.
    <boot partition size> must be >= 32 and <= 1024, or may be 0.

    Partition table on the selected drive will be deleted. New DOS partition
table will be created. Partitions will be created:

    sdX1 - 64M, type EFI, active, FAT
    sdX2 - <boot partition size>, type Linux, ext4 without journal. Skipped if
<boot partition size>==0
    sdX3 - rest, type Linux, ext4 without journal

    Under Core or Core64 grub2 will be installed for BIOS boot only. Under
Corepure64 grub2 will be installed for both BIOS and UEFI boot.

Dependencies:

    dosfstools.tcz, grub2-multi.tcz, grub.cfg.template

EOF

  exit 0
fi


#----------
# TinyCore?
#----------

uname -a | grep tinycore > /dev/null || { echo "Please, run under TinyCore Linux." ; exit 1 ; }

. /etc/init.d/tc-functions

#----------------------
# Checking dependencies
#----------------------

tce-load -w dosfstools || { echo "Can not download dosfstools.tcz" ; exit 1 ; }
tce-load -i dosfstools 

tce-load -w grub2-multi || { echo "Can not download grub2-multi.tcz" ; exit 1 ; }
tce-load -i grub2-multi

[ -f "grub.cfg.template" ] || { echo "Can not find grub.cfg.template." ; exit 1 ; }


function detect_new_drive
{
  DRIVES_PRESENT="$(ls /dev/sd?)"

  while true
  do
    sleep 1
    DRIVES_FOUND="$(ls /dev/sd?)"

    for NEW_DRIVE in $DRIVES_FOUND
    do
      echo "$DRIVES_PRESENT" | grep "$NEW_DRIVE" > /dev/null || return 0
    done
  done
}


function check_drive
{
  if [ $# -lt 1 ]
  then
    echo "No drive specified."
    return 1
  fi

  if ! [ -b "$1" ]
  then
    echo "Drive "$1" not preset in the system."
    return 2
  fi

  if [ "$1" == "/dev/sda" ]
  then
    echo "You can not use /dev/sda."
    return 3
  fi

  TCEDEVICE="$(readlink /etc/sysconfig/tcedir | sed 's_/mnt/\([^0-9/]*\).*_\1_')"

  if [ "/dev/${TCEDEVICE}" == "$1" ]
  then
    echo "You are going to destroy Your system device."
    return 4
  fi

  if [ -n "$( mount | grep $1 )" ]
  then
    echo Drive "$1" has mounted partitions.
    return 5
  fi

  return 0
}


#------------------------------------
# Selecting and checking drive to use
#------------------------------------

if [ $# -lt 1 -o "$1" == "wait" ]
then
  echo
  echo -n "Connect the drive to be repartitioned .. "
  detect_new_drive
  echo "Ok"
else
  NEW_DRIVE="$1"
fi

echo "$NEW_DRIVE selected."

check_drive $NEW_DRIVE || exit 1


#-------------------------------------------
# Selecting and checking boot partition size
#-------------------------------------------

BOOT_PART_SIZE_MIN="32"
BOOT_PART_SIZE_MAX="1024"

if [ $# -lt 2 ]
then
  echo
  echo -n "Size of the boot partition, MB [ ${BOOT_PART_SIZE_MIN} - ${BOOT_PART_SIZE_MAX} , 0 ( skip ) ] : "
  read BOOT_PART_SIZE REST
else
  BOOT_PART_SIZE="$2"
fi

echo "Requested boot partition size = $BOOT_PART_SIZE MB"

printf "%d" $BOOT_PART_SIZE > /dev/null 2>&1 || { echo "Not a decimal number : $BOOT_PART_SIZE" ;  exit 1 ; }
if [ "$BOOT_PART_SIZE" -ne 0 ]
then
  [ "$BOOT_PART_SIZE" -lt "$BOOT_PART_SIZE_MIN" ] && { echo "Must be -ge 32." ; exit 1 ; }
  [ "$BOOT_PART_SIZE" -gt "$BOOT_PART_SIZE_MAX" ] && { echo "Must be -le 1024." ; exit 1 ; }
fi


#------
# Sure?
#------

echo
echo  "You are going to destroy all data on $NEW_DRIVE drive!" 
read -p "Continue ? [yes,*] : " ANS

echo

[ "$ANS" == "yes" ] || { echo "Bye." ; exit 1 ; }


#---------------------------------------
# Determining new partitions' boundaries
#---------------------------------------

GRUB_PART_SIZE="64"

GRUB_PART_START="2048"
GRUB_PART_END="$(( $GRUB_PART_SIZE * 2048 + $GRUB_PART_START - 1 ))"

BOOT_PART_START="$(( $GRUB_PART_END + 1 ))"
BOOT_PART_END="$(( $BOOT_PART_SIZE * 2048 + $BOOT_PART_START - 1 ))"

TCE_PART_START="$(( $BOOT_PART_END + 1 ))"

FDISK_CMD=$(mktemp)

echo -e "n\np\n1\n${GRUB_PART_START}\n${GRUB_PART_END}\nt\nef\na\n1\n" >> "$FDISK_CMD"
[ $BOOT_PART_SIZE -gt 0 ] && echo -e "n\np\n2\n${BOOT_PART_START}\n${BOOT_PART_END}\n" >> "$FDISK_CMD"
echo -e "n\np\n3\n${TCE_PART_START}\n\nw" >> "$FDISK_CMD"


#-----------------------------------------
# Deleting old and creating new partitions
#-----------------------------------------

echo -n "Cleaning existing partition table .. "
sudo dd if=/dev/zero of="$NEW_DRIVE" bs=1M count=1 > /dev/null 2>&1 || { echo "failed" ; exit 1 ; } ; sync
echo "Ok" ; sleep 10

echo -n "Creating partitions .. "
cat "$FDISK_CMD" | sudo /sbin/fdisk "$NEW_DRIVE" > /dev/null 2>&1 || { echo "failed" ; exit 1 ; } ; sync
echo "Ok" ; sleep 10


rm -f "$FDISK_CMD"


#-----------------------------------------
# Formatting of already created partitions
#-----------------------------------------

echo -n "Making filesystems .. "
sudo mkfs.vfat "${NEW_DRIVE}"1 > /dev/null 2>&1 || { echo "${NEW_DRIVE}1 failed" ; exit 1 ; } ; sync
[ "$BOOT_PART_SIZE" -gt 0 ] && { echo "y" | sudo mkfs.ext4  -O ^has_journal "${NEW_DRIVE}"2 > /dev/null 2>&1  || { echo "${NEW_DRIVE}2 failed" ; exit 1 ; } ; sync ; }
echo "y" | sudo mkfs.ext4  -O ^has_journal "${NEW_DRIVE}"3 > /dev/null 2>&1 || { echo "${NEW_DRIVE}3 failed" ; exit 1 ; } ; sync

echo "Ok" ; sleep 10

sudo rebuildfstab


#----------------------------------------------------
# Creating grub.cfg, corresponding created partitions
#----------------------------------------------------

TCE_PART_UUID="$( blkid -s UUID -o value ${NEW_DRIVE}3 )"
BOOT_PART_UUID="$TCE_PART_UUID" ; BOOT_ROOT_NAME="/boot"
[ "$BOOT_PART_SIZE" -gt 0 ] && { BOOT_PART_UUID="$( blkid -s UUID -o value ${NEW_DRIVE}2 )" ; BOOT_ROOT_NAME="/." ; }

TCE_UUID_NAME='${TCE_UUID}'

cat > grub.cfg << EOF
BOOT_UUID="${BOOT_PART_UUID}"
BOOT_ROOT="${BOOT_ROOT_NAME}"
TCE_UUID="${TCE_PART_UUID}"

BOOTCODES_DEF="waitusb=10:UUID=${TCE_UUID_NAME}"

EOF

cat grub.cfg.template >> grub.cfg


#--------------------------------------------
# Install grub and copy grub.cfg on its place
#--------------------------------------------

GRUB_PART_MNT="$(cat /etc/fstab | grep ${NEW_DRIVE}1 | awk '{ print $2 }')"

sudo mount "${NEW_DRIVE}"1 ; sleep 1
[ "$(getBuild)" == "x86_64" ] && sudo grub-install --target=x86_64-efi --boot-directory="${GRUB_PART_MNT}"/EFI/BOOT --efi-directory="${GRUB_PART_MNT}" --removable
sudo grub-install --target=i386-pc --boot-directory="${GRUB_PART_MNT}"/EFI/BOOT "$NEW_DRIVE"
sudo cp grub.cfg "${GRUB_PART_MNT}"/EFI/BOOT/grub
sudo umount "${NEW_DRIVE}"1


exit 0


