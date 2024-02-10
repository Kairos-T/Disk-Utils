#!/bin/bash

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Check for sudo permissions
if [ "$EUID" -ne 0 ]; then
  log "Please run this script as root!"
  exit 1
fi

display_disk_info() {
  local disk="$1"
  log "Disk Information for $disk:"
  fdisk -l "$disk"
}

image_disk() {
  fdisk -l
  read -rp "Enter the path of the disk to image (e.g., /dev/sda1): " disk

  if [ ! -e "$disk" ]; then
    log "Error: Disk '$disk' not found."
    return 1
  fi

  display_disk_info "$disk"

  read -rp "Proceed to image the disk? [y/N] " response
  if [[ ! "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    log "Disk imaging aborted."
    return 1
  fi

  read -rp "Enter the path to save the image (e.g., Downloads/disk.img): " path

  if [ ! -d "$(dirname "$path")" ]; then
    log "Error: Directory '$(dirname "$path")' does not exist."
    return 1
  fi

  dd if="$disk" of="$path" bs=4M status=progress
  log "Disk imaging completed successfully."
}

securely_erase_disk() {
    fdisk -l
  read -rp "Enter the disk to erase (e.g., /dev/sda1): " disk

  if [ ! -e "$disk" ]; then
    log "Error: Disk '$disk' not found."
    return 1
  fi

  display_disk_info "$disk"

  read -rp "Proceed to erase the disk? [y/N] " response
  if [[ ! "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    log "Disk erasure aborted."
    return 1
  fi

  dd if=/dev/urandom of="$disk" bs=4k status=progress
  log "Disk securely erased successfully."
}

PS3='Enter your choice: '
select choice in "Image Disk" "Securely Erase Disk" "Exit"
do
  case $choice in
    "Image Disk")
      image_disk
      ;;
    "Securely Erase Disk")
      securely_erase_disk
      ;;
    "Exit")
      log "Exiting the script."
      break
      ;;
    *)
      log "Invalid option!"
      break
      ;;
  esac
done