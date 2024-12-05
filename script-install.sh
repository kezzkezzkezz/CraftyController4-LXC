#!/usr/bin/env bash

source <(curl -s https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)

# Function definitions
function default_settings() {
    CT_TYPE="${CT_TYPE:-1}"  # Set default container type
    PW=""
    CT_ID=$NEXTID
    HN=$NSAPP
    DISK_SIZE="${var_disk:-20}"
    CORE_COUNT="${var_cpu:-2}"
    RAM_SIZE="${var_ram:-2048}"
    BRG="vmbr0"
    NET="dhcp"
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
    pct exec $CT_ID -- bash -c "apt update && apt upgrade -y"
    pct exec $CT_ID -- bash -c "apt install -y git openjdk-21-jdk"
    pct exec $CT_ID -- bash -c "git clone https://gitlab.com/crafty-controller/crafty-installer-4.0.git"
    pct exec $CT_ID -- bash -c "cd crafty-installer-4.0 && ./install_crafty.sh"
    msg_ok "Crafty successfully installed"
}

# Main script execution
variables            # Load default variables
default_settings     # Call after function is defined
build_container      # Build LXC
install_crafty       # Install Crafty

msg_ok "Completed Successfully!"
