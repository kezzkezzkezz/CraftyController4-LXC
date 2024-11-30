#!/usr/bin/env bash
# Crafty LXC Container Installation Script for Proxmox VE

# Strict error handling
set -euo pipefail

# Ensure script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root on a Proxmox VE host" 
   exit 1
fi

# Configuration variables
APP="Crafty"
var_disk="20"  # Disk size in GB
var_cpu="2"    # CPU cores
var_ram="2048" # RAM size in MB

# Function to list storage pools and prompt the user to select one
select_storage_pool() {
    local POOLS
    # Use local storage or use grep to filter only certain types if needed
    POOLS=$(pvesm status | awk 'NR>1 && $2 ~ /dir|zfs|lvm|lvmthin/ {print $1 " - " $2 " - Available: " $4}')
    
    # Check if pools are found
    if [[ -z "$POOLS" ]]; then
        echo "No compatible storage pools found. Ensure Proxmox storage is configured."
        exit 1
    fi
    
    # Fallback to first pool if only one exists
    if [[ $(echo "$POOLS" | wc -l) -eq 1 ]]; then
        echo "$POOLS" | awk '{print $1}'
        return
    fi
    
    # Use whiptail or dialog for interactive selection
    whiptail --title "Select Storage Pool" --menu \
        "Choose a storage pool for the container:" 20 78 10 \
        $(echo "$POOLS" | awk '{print NR " " $0}') 3>&1 1>&2 2>&3
}

# Function to find a unique container ID
find_next_ct_id() {
    local start_id=100
    local max_id=999
    for ((id=start_id; id<=max_id; id++)); do
        if ! pct status "$id" &>/dev/null; then
            echo "$id"
            return
        fi
    done
    echo "No available container IDs found between $start_id and $max_id!" >&2
    exit 1
}

# Main script execution
main() {
    echo -e "Loading Crafty LXC Container Installation...\n"

    # Select storage pool
    STORAGE_POOL=$(select_storage_pool)
    echo "Selected storage pool: $STORAGE_POOL"

    # Find container ID
    CT_ID=$(find_next_ct_id)
    echo "Using container ID: $CT_ID"

    # Verify storage pool exists and is valid
    if ! pvesm status | grep -q "^$STORAGE_POOL\b"; then
        echo "Error: Selected storage pool '$STORAGE_POOL' does not exist or is invalid!"
        exit 1
    fi

    # Build container
    build_container "$STORAGE_POOL" "$CT_ID"
    
    echo "${APP} LXC Container Installation Completed Successfully!"
}

# Function to build the container
build_container() {
    local STORAGE_POOL=$1
    local CT_ID=$2
    local HN="crafty-container"

    # Download container template if not exists
    pveam update
    pveam download local debian-12-standard_12.7-1_amd64.tar.zst || true

    # Create container
    pct create "$CT_ID" "local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst" \
        --hostname "$HN" \
        --rootfs "$STORAGE_POOL:${var_disk}" \
        --cores "$var_cpu" \
        --memory "$var_ram" \
        --net0 "bridge=vmbr0,name=eth0,ip=dhcp" \
        --password "CraftyAdmin2024!" \
        --unprivileged 1

    # Start the container
    pct start "$CT_ID"
    
    # Optional: wait and verify container status
    sleep 5
    pct status "$CT_ID"
}

# Run main function
main
