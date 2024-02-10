#!/bin/bash

# Define colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
  echo -e "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Check for sudo permissions
if [ "$EUID" -ne 0 ]; then
  log "${RED}Please run this script as root!${NC}"
  exit 1
fi

display_disk_info() {
  local disk="$1"
  log "${YELLOW}Disk Information for $disk:${NC}"
  fdisk -l "$disk"
}

image_disk() {
  fdisk -l
  read -rp "Enter the path of the disk to image (e.g., ${YELLOW}/dev/sda1${NC}): " disk

  if [ ! -e "$disk" ]; then
    log "${RED}Error: Disk '$disk' not found.${NC}"
    return 1
  fi

  display_disk_info "$disk"

  read -rp "${YELLOW}Proceed to image the disk? [y/N] ${NC}" response
  if [[ ! "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    log "${YELLOW}Disk imaging aborted.${NC}"
    return 1
  fi

  read -rp "Enter the path to save the image (e.g., ${YELLOW}Downloads/disk.img${NC}): " path

  if [ ! -d "$(dirname "$path")" ]; then
    log "${RED}Error: Directory '$(dirname "$path")' does not exist.${NC}"
    return 1
  fi

  dd if="$disk" of="$path" bs=4M status=progress
  log "${GREEN}Disk imaging completed successfully.${NC}"
}

securely_erase_disk() {
  fdisk -l
  read -rp "Enter the disk to erase (e.g., ${YELLOW}/dev/sda1${NC}): " disk

  if [ ! -e "$disk" ]; then
    log "${RED}Error: Disk '$disk' not found.${NC}"
    return 1
  fi

  display_disk_info "$disk"

  read -rp "${YELLOW}Proceed to erase the disk? [y/N] ${NC}" response
  if [[ ! "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    log "${YELLOW}Disk erasure aborted.${NC}"
    return 1
  fi

  dd if=/dev/urandom of="$disk" bs=4k status=progress
  log "${GREEN}Disk securely erased successfully.${NC}"
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
      log "${YELLOW}Exiting the script.${NC}"
      break
      ;;
    *)
      log "${RED}Invalid option!${NC}"
      break
      ;;
  esac
done