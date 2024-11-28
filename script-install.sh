#!/usr/bin/env bash
# Crafty LXC Container Installation Script
# Copyright (c) 2024
# Author: kezzkezzkezz
# License: MIT
# https://github.com/kezzkezzkezz/CraftyController4-lxc/blob/main/LICENSE

# Download build functions
source <(curl -s https://raw.githubusercontent.com/kezzkezzkezz/CraftyController4-lxc/main/build.func)

# Script initialization
echo -e "Loading Crafty LXC Container Installation..."

# Application and container configuration
APP="Crafty"
var_disk="20"     # Disk size in GB
var_cpu="2"       # Number of CPU cores
var_ram="2048"    # RAM in MB
var_os="debian"   # Operating system
var_version="12"  # OS version

# Call core functions
variables
color
catch_errors

# Default container settings function
function default_settings() {
    CT_TYPE="1"               # Container type (1 = LXC)
    PASSWORD=""               # Optional password
    CT_ID=$NEXTID             # Next available Container ID
    HN=$NSAPP                 # Hostname
    DISK_SIZE="$var_disk"     # Disk size
    CORE_COUNT="$var_cpu"     # CPU cores
    RAM_SIZE="$var_ram"       # RAM size
    BRG="vmbr0"               # Bridge interface
    NET="dhcp"                # Network configuration
    
    # Additional optional settings
    PORT=""
    GATE=""
    APT_CACHER=""
    APT_CACHER_IP=""
    DISABLEIP6="no"
    MTU=""
    SD=""
    MAC=""
    VLAN=""
    SSH="no"
    VERBOSE="no"
    
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

    # Select LVM storage or use default
    SELECTED_LVM=$(select_lvm)

    # Create the container
    pct create $CT_ID $SELECTED_LVM:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst \
        --hostname $HN \
        --rootfs $SELECTED_LVM:$DISK_SIZE \
        --cores $CORE_COUNT \
        --memory $RAM_SIZE \
        --net0 name=eth0,bridge=$BRG,ip=$NET

    # Start the container
    pct start $CT_ID
    msg_ok "Container built successfully."
}

# Main installation process
start
build_container
default_settings
description
install_crafty

# Final messages
msg_ok "Crafty LXC Container Installation Completed Successfully!\n"
echo -e "${APP} should be accessible once configured and started.\n"
