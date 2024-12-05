#!/usr/bin/env bash
source <(curl -s https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)
VERB="off"  # Fix unbound variable error
APP="Crafty"
var_disk="20"
var_cpu="2"
var_ram="2048"
var_os="debian"
var_version="12"

variables          # Initialize required variables like NEXTID
default_settings    # Set container defaults
catch_errors        # Trap errors for better debugging

function install_crafty() {
    msg_info "Installing Crafty in the LXC container"

    # Fix locale issues
    pct exec $CT_ID -- bash -c "apt install -y locales && locale-gen en_US.UTF-8 && update-locale LANG=en_US.UTF-8"

    # Update and upgrade packages
    pct exec $CT_ID -- bash -c "apt update && apt upgrade -y"

    # Install dependencies
    pct exec $CT_ID -- bash -c "apt install git openjdk-21-jdk -y"

    # Clone Crafty repository and install
    pct exec $CT_ID -- bash -c "git clone https://gitlab.com/crafty-controller/crafty-installer-4.0.git"
    pct exec $CT_ID -- bash -c "cd crafty-installer-4.0 && ./install_crafty.sh"

    msg_ok "Crafty successfully installed"
}

function get_ip() {
    msg_info "Retrieving the container's IP address"
    IP=$(pct exec $CT_ID -- hostname -I | awk '{print $1}')
    if [[ -z "$IP" ]]; then
        msg_error "Failed to retrieve the container's IP address"
        exit 1
    fi
    msg_ok "IP Address: $IP"
}

build_container      # Create the LXC container
install_crafty       # Install Crafty
get_ip               # Retrieve and display the IP address

msg_ok "Completed Successfully!\n"
echo -e "${APP} should be reachable by going to the following URL:
         http://${IP}:8000 \n"
