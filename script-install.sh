#!/usr/bin/env bash
source <(curl -s https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)
# Copyright (c) 2021-2024 tteck
# Author: tteck
# Co-Author: MickLesk (Canbiz)
# License: MIT
# https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/matze/wastebin
# Function definitions

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
APP="Wastebin"
var_disk="4"
var_cpu="1"
var_ram="1024"
var_os="debian"
var_version="12"
variables
color
catch_errors

function install_crafty() {
    msg_info "Installing Crafty in the LXC container"
    pct exec $CT_ID -- bash -c "apt update && apt upgrade -y"
    pct exec $CT_ID -- bash -c "apt install -y git openjdk-21-jdk"
    pct exec $CT_ID -- bash -c "git clone https://gitlab.com/crafty-controller/crafty-installer-4.0.git"
    pct exec $CT_ID -- bash -c "cd crafty-installer-4.0 && ./install_crafty.sh"
    msg_ok "Crafty successfully installed"
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${APP} Setup should be reachable by going to the following URL.
         ${BL}http://${IP}:8088${CL} \n"

msg_ok "Completed Successfully!"
