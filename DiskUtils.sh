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

# Check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Check for required dependencies
check_dependencies() {
  local dependencies=("lsblk" "dd" "mkfs" "grep" "umount")
  local optional_dependencies=("exfat-utils" "ntfs-3g")

  for cmd in "${dependencies[@]}"; do
    if ! command_exists "$cmd"; then
      log "${RED}Error: Required dependency '$cmd' is missing. Please install it and try again.${NC}"
      exit 1
    fi
  done

  for cmd in "${optional_dependencies[@]}"; do
    if ! command_exists "$cmd"; then
      log "${YELLOW}Warning: Optional dependency '$cmd' is missing. Some features may not work (e.g., exFAT/NTFS formatting).${NC}"
    fi
  done
}

# Disk or partition validation
is_valid_disk() {
  local disk="$1"

  if [ ! -e "$disk" ]; then
    log "${RED}Error: Disk '$disk' not found.${NC}"
    return 1
  fi

  if mount | grep -q "$disk"; then
    log "${YELLOW}Disk '$disk' is currently mounted. It must be unmounted.${NC}"
    echo -e -n "${YELLOW}Would you like to unmount it? [y/N] ${NC}"
    read -r response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
      if umount "$disk"; then
        log "${GREEN}Disk '$disk' unmounted successfully.${NC}"
      else
        log "${RED}Failed to unmount disk '$disk'. Please unmount it manually.${NC}"
        return 1
      fi
    else
      log "${YELLOW}Operation aborted. Disk must be unmounted before proceeding.${NC}"
      return 1
    fi
  fi

  return 0
}

display_disk_info() {
  local disk="$1"
  log "${YELLOW}Disk Information for $disk:${NC}"
  lsblk "$disk"
}

image_disk() {
  lsblk -o NAME,SIZE,TYPE,MOUNTPOINT
  echo -e -n "Enter the path of the disk to image (e.g., ${YELLOW}/dev/sda or /dev/sda1${NC}): "
  read -r disk

  if ! is_valid_disk "$disk"; then
    return 1
  fi

  display_disk_info "$disk"

  echo -e -n "${YELLOW}Proceed to image the disk? [y/N] ${NC}"
  read -r response
  if [[ ! "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    log "${YELLOW}Disk imaging aborted.${NC}"
    return 1
  fi

  echo -e -n "Enter the path to save the image (e.g., ${YELLOW}/Downloads/disk.img${NC}): "
  read -r path

  if [ ! -d "$(dirname "$path")" ]; then
    log "${RED}Error: Directory '$(dirname "$path")' does not exist.${NC}"
    return 1
  fi

  if dd if="$disk" of="$path" bs=4M status=progress; then
    log "${GREEN}Disk imaging completed successfully.${NC}"
  else
    log "${RED}Disk imaging failed.${NC}"
  fi
}

securely_erase_disk() {
  lsblk -o NAME,SIZE,TYPE,MOUNTPOINT | grep --color=never -E 'disk|part'
  echo -e -n "Enter the disk to erase (e.g., ${YELLOW}/dev/sda or /dev/sda1${NC}): "
  read -r disk

  if ! is_valid_disk "$disk"; then
    return 1
  fi

  display_disk_info "$disk"
  echo -e -n "Enter the number of passes for disk erasure (default is 1): "
  read -r response

  # Default to 1 if no response is given
  passes=${response:-1}

  echo -e -n "${YELLOW}Proceed to erase the disk? [y/N] ${NC}"
  read -r response
  if [[ ! "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    log "${YELLOW}Disk erasure aborted.${NC}"
    return 1
  fi

  for ((i = 1; i <= passes; i++)); do
    if dd if=/dev/urandom of="$disk" bs=4k status=progress 2>&1 | tee /tmp/dd_output.log | grep -q "No space left on disk"; then
      log "${GREEN}Pass $i/$passes completed successfully.${NC}"
    else
      log "${RED}Pass $i: Disk erasure failed.${NC}"
      return 1
    fi
  done

  log "${GREEN}Disk erasure completed successfully. If you want to continue using the disk, format it (option 3).${NC}"
}

format_disk() {
    lsblk -o NAME,SIZE,TYPE,MOUNTPOINT | grep --color=never -E 'disk|part'
    echo -e -n "Enter the disk to format (e.g., ${YELLOW}/dev/sda or /dev/sda1${NC}): "
    read -r disk

    if ! is_valid_disk "$disk"; then
      return 1
    fi

    display_disk_info "$disk"

    echo -e "1. Format as ext4 filesystem (used for Linux)"
    echo -e "2. Format as NTFS filesystem (used for Windows)"
    echo -e "3. Format as FAT32 filesystem (used for USB drives)"
    echo -e "4. Format as exFAT filesystem (used for USB drives)"
    echo -e -n "${YELLOW}Choose the format option:${NC} "
    read -r format_choice

    case $format_choice in
      1)
        mkfs.ext4 "$disk"
        log "${GREEN}Disk formatted as ext4 filesystem successfully.${NC}"
        ;;
      2)
        mkfs.ntfs "$disk" || log "${RED}Failed to format disk as NTFS. Ensure ntfs-3g is installed.${NC}"
        ;;
      3)
        mkfs.fat -F32 "$disk"
        log "${GREEN}Disk formatted as FAT32 filesystem successfully.${NC}"
        ;;
      4)
        mkfs.exfat "$disk" || log "${RED}Failed to format disk as exFAT. Ensure exfat-utils is installed.${NC}"
        ;;
      *)
        log "${RED}Invalid option!${NC}"
        return 1
        ;;
    esac
}

# Run dependency check at the beginning
check_dependencies

PS3='Choose an option (1-4): '
while true; do
  select choice in "Image Disk" "Securely Erase Disk" "Format Disk" "Exit"; do
    case $choice in
      "Image Disk")
        image_disk
        break
        ;;
      "Securely Erase Disk")
        securely_erase_disk
        break
        ;;
      "Format Disk")
        format_disk
        break
        ;;
      "Exit")
        log "${YELLOW}Exiting the script.${NC}"
        exit 0
        ;;
      *)
        log "${RED}Invalid option!${NC}"
        ;;
    esac
  done
done
