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

# Core functions

variables() {
    NSAPP="${APP:-UnknownApp}"
    NEXTID=$(pvesh get /cluster/nextid)
}

color() {
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m' # No Color
}

catch_errors() {
    trap 'error_handler $LINENO' ERR
}

error_handler() {
    local line_number=$1
    echo -e "${RED}[ERROR]${NC} An error occurred on line $line_number"
    echo -e "${YELLOW}[WARN]${NC} Command that failed: $BASH_COMMAND"
    exit 1
}

msg_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

msg_ok() {
    echo -e "${GREEN}[OK]${NC} $1"
}

msg_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

msg_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Default container settings function
function default_settings() {
    CT_TYPE="1"               # Container type (1 = LXC)
    PASSWORD=""               # Optional password
    CT_ID=$NEXTID             # Next available Container ID (Ensure NEXTID is valid or hardcode)
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
    msg_info "Building LXC container..."

    # Create the container without using select_lvm
    pct create $CT_ID /var/lib/vz/template/cache/debian-12-standard_12.7-1_amd64.tar.zst \
        --hostname $HN \
        --rootfs /var/lib/vz/$DISK_SIZE \
        --cores $CORE_COUNT \
        --memory $RAM_SIZE \
        --net0 name=eth0,bridge=$BRG,ip=$NET

    # Start the container
    pct start $CT_ID
    msg_ok "Container built successfully."
}

# Main installation process
start() {
    # Ensure script is run as root
    if [[ $EUID -ne 0 ]]; then
        msg_error "This script must be run as root"
        exit 1
    fi
    
    msg_info "Initializing ${APP:-Application} LXC Container Installation"
}

# Run the installation steps
start
variables
color
catch_errors
build_container
default_settings
install_crafty

# Final messages
msg_ok "Crafty LXC Container Installation Completed Successfully!\n"
echo -e "${APP} should be accessible once configured and started.\n"
