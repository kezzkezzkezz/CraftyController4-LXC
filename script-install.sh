#!/usr/bin/env bash
source <(curl -s https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)
# Source: https://github.com/community-scripts/
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
APP="CraftyController4"
var_disk="20"
var_cpu="10"
var_ram="10024"
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

function update_script() {
header_info
check_container_storage
check_container_resources
if [[ ! -d /var/opt/minecraft/crafty ]]; then msg_error "No ${APP} Installation Found!"; exit; fi
msg_info "Updating $APP LXC"
apt update && apt upgrade -y  &>/dev/null
apt install -y git openjdk-21-jdk  &>/dev/null
git clone https://gitlab.com/crafty-controller/crafty-installer-4.0.git  &>/dev/null
cd crafty-installer-4.0 && ./install_crafty.sh &>/dev/null
msg_ok "Crafty successfully installed"
}

msg_info "Starting Craft Controller"
systemctl start crafty
msg_ok "Started Craft Controller"
msg_ok "Updated Successfully"
exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${APP} Setup should be reachable by going to the following URL.
         ${BL}http://${IP}:8000${CL} \n"

msg_ok "Completed Successfully!"
