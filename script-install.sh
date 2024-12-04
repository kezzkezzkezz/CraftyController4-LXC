#!/usr/bin/env bash
source <(curl -s https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)
# Copyright (c) 2021-2024 tteck
# Author: tteck (tteckster)
# License: MIT
# https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE

function header_info {
clear
cat <<"EOF"
   ____ _          ____ _           ____              _     
  / ___| |__   ___| __ ) | ___ _ __|  _ \ _ __ ___   / \    
 | |   | '_ \ / _ \  _ \ |/ _ \ '__| |_) | '_ ` _ \ / _ \   
 | |___| | | |  __/ |_) | |  __/ |  |  __/| | | | | / ___ \  
  \____|_| |_|\___|____/|_|\___|_|  |_|   |_| |_| |_/_/   \_\
EOF
}
header_info
echo -e "Loading..."
APP="Crafty Controller"
var_disk="2"
var_cpu="1"
var_ram="512"
var_os="debian"
var_version="12"
variables
color
catch_errors

function default_settings() {
  CT_TYPE="1"
  PW=""
  CT_ID=$NEXTID
  HN=$NSAPP
  DISK_SIZE="$var_disk"
  CORE_COUNT="$var_cpu"
  RAM_SIZE="$var_ram"
  BRG="vmbr0"
  NET="dhcp"
  GATE=""
  APT_CACHER=""
  APT_CACHER_IP=""
  DISABLEIP6="no"
  MTU=""
  SD=""
  NS=""
  MAC=""
  VLAN=""
  SSH="no"
  VERB="no"
  echo_default
}

function install_crafty() {
  header_info
  check_container_storage
  check_container_resources

  msg_info "Installing ${APP}"
  
  # Install necessary dependencies
  apt update && apt install -y curl unzip git

  # Download Crafty Controller 4
  cd /opt
  git clone https://github.com/crafty-ctrl/crafty-controller.git
  cd crafty-controller

  # Install Crafty Controller dependencies
  ./install.sh
  
  msg_ok "Crafty Controller Installation Complete"

  msg_info "Starting ${APP}"
  systemctl enable crafty
  systemctl start crafty
  msg_ok "Started ${APP}"

  msg_ok "Installation Successful"
  echo -e "${APP} should be reachable by going to the following URL: ${BL}http://<Your-Server-IP>:8080${CL}"
}

function update_crafty() {
  header_info
  check_container_storage
  check_container_resources
  if [[ ! -d /opt/crafty-controller ]]; then msg_error "No ${APP} Installation Found!"; exit; fi
  msg_info "Stopping ${APP}"
  systemctl stop crafty
  msg_ok "Stopped ${APP}"

  msg_info "Updating ${APP}"
  cd /opt/crafty-controller
  git pull origin main
  msg_ok "Updated ${APP}"

  msg_info "Starting ${APP}"
  systemctl start crafty
  msg_ok "Started ${APP}"
  msg_ok "Updated Successfully"
  exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
