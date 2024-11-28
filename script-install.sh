#!/usr/bin/env bash
# Crafty LXC Container Installation Script
# Copyright (c) 2024
# Author: kezzkezzkezz
# License: MIT
# https://github.com/kezzkezzkezz/CraftyController4-lxc/blob/main/LICENSE

# Script initialization
echo -e "Loading Crafty LXC Container Installation..."

# Application and container configuration
APP="Crafty"
var_disk="20"     # Disk size in GB
var_cpu="2"       # Number of CPU cores
var_ram="2048"    # RAM in MB
var_os="debian"   # Operating system
var_version="12"  # OS version

# Placeholder functions (for now)
variables() {
  NEXTID=$(pvesh get /nodes/gigabirtha/lxc | jq '.[] | .vmid' | sort -n | tail -n 1)
  NEXTID=$((NEXTID+1))
}

color() {
  # Placeholder for color output
  GREEN='\033[0;32m'
  NC='\033[0m' # No Color
}

catch_errors() {
  # Simple error handling function
  trap 'echo -e "${RED}An error occurred. Exiting.${NC}"' ERR
}

msg_info() {
  echo -e "${GREEN}INFO: $1${NC}"
}

msg_ok() {
  echo -e "${GREEN}OK: $1${NC}"
}

echo_default() {
  # Just a placeholder to show settings
  echo -e "Container ID: $CT_ID"
  echo -e "Hostname: $HN"
  echo -e "Disk Size: $DISK_SIZE"
  echo -e "CPU: $CORE_COUNT cores"
  echo -e "RAM: $RAM_SIZE MB"
}

# Function to list available LVM volume groups
list_available_vgs() {
    echo "Available LVM Volume Groups:"
    vgs --noheadings -o vg_name
}

# Function to select LVM or standard disk setup
select_disk_setup() {
    read -p "Do you want to use LVM for the disk setup? (y/n): " use_lvm
    if [[ "$use_lvm" =~ ^[Yy]$ ]]; then
        list_available_vgs
        read -p "Enter the volume group name to use for LVM: " selected_vg
        if ! vgs "$selected_vg" > /dev/null 2>&1; then
            echo "Invalid volume group selected."
            exit 1
        fi
        DISK_TYPE="lvm"
        DISK_PATH="${selected_vg}:${DISK_SIZE}G"
    else
        DISK_TYPE="standard"
        DISK_PATH="local:${DISK_SIZE}G"
    fi
}

# Default container settings function
function default_settings() {
    CT_TYPE="1"               # Container type (1 = LXC)
    PASSWORD=""               # Optional password
    CT_ID=$NEXTID             # Next available Container ID
    HN="crafty-container"     # Use a valid DNS-compatible hostname
    DISK_SIZE="$var_disk"     # Disk size
    CORE_COUNT="$var_cpu"     # CPU cores
    RAM_SIZE="$var_ram"       # RAM size
    BRG="vmbr0"               # Bridge interface
    NET="dhcp"                # Network configuration
    
    # Display default settings
    echo_default
}

# Crafty installation function
function install_crafty() {
    msg_info "Installing Crafty in the LXC container"
    
    # Update and upgrade packages
    pct exec $CT_ID -- bash -c "apt update && apt upgrade -y"
    
    # Install required dependencies
    pct exec $CT_ID -- bash -c "apt install -y \
        git \
        wget \
        curl \
        openjdk-21-jdk \
        python3 \
        python3-pip \
        python3-venv"
    
    # Clone and run Crafty installer
    pct exec $CT_ID -- bash -c "
        git clone https://gitlab.com/crafty-controller/crafty-installer-4.0.git &&
        cd crafty-installer-4.0 &&
        sudo ./install_crafty.sh
    "
    
    msg_ok "Crafty successfully installed"
}

# Build the container
function build_container() {
    select_disk_setup
    pct create $CT_ID /var/lib/vz/template/cache/debian-12-standard_12.7-1_amd64.tar.zst \
    --hostname $HN \
    --rootfs $DISK_PATH \
    --cores $CORE_COUNT \
    --memory $RAM_SIZE \
    --net0 bridge=vmbr0,ip=dhcp
    pct start $CT_ID
    msg_ok "Container built successfully."
}

# Main installation process
variables
color
catch_errors
build_container
default_settings
install_crafty

# Final messages
msg_ok "Crafty LXC Container Installation Completed Successfully!\n"
echo -e "${APP} should be accessible once configured and started.\n"
