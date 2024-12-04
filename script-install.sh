#!/usr/bin/env bash
# Ensure that the external functions are sourced properly
source <(curl -s https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)

# Copyright (c) 2024
# Author: Fabacks
# License: MIT
# https://github.com/Fabacks/crafty-lxc/blob/main/LICENSE

# Display header with ASCII art
function header_info {
    clear
    cat <<"EOF"
  ____            __ _            ____            _             _ _             _  _   
 / ___|_ __ __ _ / _| |_ _   _   / ___|___  _ __ | |_ _ __ ___ | | | ___ _ __  | || |  
| |   | '__/ _` | |_| __| | | | | |   / _ \| '_ \| __| '__/ _ \| | |/ _ \ '__| | || |_ 
| |___| | | (_| |  _| |_| |_| | | |__| (_) | | | | |_| | | (_) | | |  __/ |    |__   _|
 \____|_|  \__,_|_|  \__|\__, |  \____\___/|_| |_|\__|_|  \___/|_|_|\___|_|       |_|  
                         |___/                                                         
EOF
}

header_info

# Define missing functions
function msg_info() {
    echo -e "\033[1;34m[INFO]\033[0m $1"
}

function msg_ok() {
    echo -e "\033[1;32m[OK]\033[0m $1"
}

function msg_error() {
    echo -e "\033[1;31m[ERROR]\033[0m $1"
}

function color() {
    BL="\033[1;34m"
    CL="\033[0m"
}

function catch_errors() {
    trap 'msg_error "An error occurred. Exiting..."; exit 1' ERR
}

function variables() {
    NEXTID=$(pct list | awk '{print $1}' | sort -n | tail -n 1)
    NEXTID=$((NEXTID + 1))
    NSAPP="crafty-${NEXTID}"
}

# Define settings
APP="Crafty"
var_disk="20"
var_cpu="2"
var_ram="2048"
var_os="debian"
var_version="12"

# Default settings for container
function default_settings() {
    CT_TYPE="1"
    PASSWORD=""
    CT_ID=$NEXTID
    HN=$NSAPP
    DISK_SIZE="$var_disk"
    CORE_COUNT="$var_cpu"
    RAM_SIZE="$var_ram"
    BRG="vmbr0"
    NET="dhcp"
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
}

# Function to install Crafty inside the container
function install_crafty() {
    msg_info "Installing Crafty in the LXC container"

    # Update and upgrade packages in the container
    pct exec $CT_ID -- bash -c "apt update && apt upgrade -y"

    # Install necessary dependencies: Git and OpenJDK 21
    pct exec $CT_ID -- bash -c "apt install git openjdk-21-jdk -y"

    # Clone Crafty installer repository
    pct exec $CT_ID -- bash -c "git clone https://gitlab.com/crafty-controller/crafty-installer-4.0.git"

    # Change directory and run the install script
    pct exec $CT_ID -- bash -c "cd crafty-installer-4.0 && sudo ./install_crafty.sh"

    msg_ok "Crafty successfully installed"
}

# Function to start the installation process
function start() {
    echo -e "Starting Crafty installation process..."
}

# Function to build the LXC container
function build_container() {
    pct create $CT_ID /var/lib/vz/template/cache/debian-${var_version}-amd64.tar.gz -storage local -net0 name=eth0,bridge=$BRG,ip=$NET
    pct start $CT_ID
}

# Run installation process
variables
start
build_container
default_settings
install_crafty

msg_ok "Completed Successfully!\n"
echo -e "${APP} should be reachable by going to the following URL: \n"
echo -e "${BL}http://${IP}:8000${CL} \n"
