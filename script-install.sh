#!/usr/bin/env bash
source <(curl -s https://raw.githubusercontent.com/Fabacks/crafty-lxc/main/build.func)
# Copyright (c) 2024
# Author: Fabacks
# License: MIT
# https://github.com/Fabacks/crafty-lxc/blob/main/LICENSE

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
echo -e "Loading..."
APP="Crafty"
var_disk="20"
var_cpu="2"
var_ram="2048"
var_os="debian"
var_version="12"
variables
color
catch_errors

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
    echo_default
}

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

start
build_container
default_settings
description
install_crafty

msg_ok "Completed Successfully!\n"
echo -e "${APP} should be reachable by going to the following URL.
         ${BL}http://${IP}:8000${CL} \n"
