#!/usr/bin/env bash
# Crafty LXC Container Installation Script

echo -e "Loading Crafty LXC Container Installation..."

# Configuration variables
APP="Crafty"
var_disk="20"  # Disk size in GB
var_cpu="2"    # CPU cores
var_ram="2048" # RAM size in MB

# Function to list storage pools and prompt the user to select one
select_storage_pool() {
    local POOLS
    local SELECTED_POOL

    # Gather available storage pools
    POOLS=$(pvesm status | awk 'NR>1 {print $1 " - " $2 " - Available: " $4}')

    # Check if pools are found
    if [[ -z "$POOLS" ]]; then
        echo "No storage pools found. Please ensure your Proxmox VE storage is configured."
        exit 1
    fi

    # Use whiptail to prompt the user
    SELECTED_POOL=$(whiptail --title "Select Storage Pool" --menu \
        "Choose a storage pool for the container:" 20 78 10 \
        $(echo "$POOLS" | awk '{print NR " " $0}') 3>&1 1>&2 2>&3)

    # Exit if canceled
    if [[ -z "$SELECTED_POOL" ]]; then
        echo "Storage pool selection canceled."
        exit 1
    fi

    # Extract the selected storage pool
    echo "$POOLS" | awk "NR==$SELECTED_POOL {print \$1}"
}

# Get the selected storage pool
STORAGE_POOL=$(select_storage_pool)
echo "Selected storage pool: $STORAGE_POOL"

# Function to build the container
build_container() {
    CT_ID="100"  # Example container ID
    HN="crafty-container"
    pct create "$CT_ID" "$STORAGE_POOL:debian-12-standard_12.7-1_amd64.tar.zst" \
        --hostname "$HN" \
        --rootfs "$STORAGE_POOL:${var_disk}G" \
        --cores "$var_cpu" \
        --memory "$var_ram" \
        --net0 "bridge=vmbr0,name=eth0,ip=dhcp" \
        --features nesting=1
    pct start "$CT_ID"
    echo "Container built successfully."
}

# Build and install
build_container
echo "${APP} LXC Container Installation Completed Successfully!"
