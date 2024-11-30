#!/usr/bin/env bash
# Crafty LXC Container Installation Script

# Validate Container ID
validate_ctid() {
    local CTID="$1"
    
    # Validate that CTID is a number
    if ! [[ "$CTID" =~ ^[0-9]+$ ]]; then
        echo "Error: Container ID must be a number."
        return 1
    fi  # Correctly close the if condition
}
    
    # Ensure ID is at least 100
    if [ "$CTID" -lt 100 ]; then
        echo "Error: Container ID cannot be less than 100."
        return 1
    fi
    
    # Ensure ID is no more than 999
    if [ "$CTID" -gt 999 ]; then
        echo "Error: Container ID cannot be greater than 999."
        return 1
    fi
    
    # Check if ID is already in use
    if pct status "$CTID" &>/dev/null; then
        echo "Error: Container ID $CTID is already in use."
        return 1
    fi
    
    return 0
}

# Function to find a unique container ID
find_next_ct_id() {
    for id in $(seq 100 999); do
        if validate_ctid "$id"; then
            echo "$id"
            return
        fi
    done
    echo "No available container IDs found!" >&2
    exit 1
}

# Configuration variables
APP="Crafty"
var_disk="20"  # Disk size in GB
var_cpu="2"    # CPU cores
var_ram="2048" # RAM size in MB

# Function to list storage pools and prompt the user to select one
select_storage_pool() {
    local POOLS
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

# Ensure script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root on a Proxmox VE host" 
   exit 1
fi

# Get the selected storage pool
STORAGE_POOL=$(select_storage_pool)
echo "Selected storage pool: $STORAGE_POOL"

# Find an available container ID
CT_ID=$(find_next_ct_id)
echo "Using container ID: $CT_ID"

# Ensure storage pool is valid and exists
if ! pvesm status | grep -q "^$STORAGE_POOL"; then
    echo "Selected storage pool does not exist or is invalid!"
    exit 1
fi

# Function to build the container
build_container() {
    local HN="crafty-container"
    pct create "$CT_ID" "$STORAGE_POOL:debian-12-standard_12.7-1_amd64.tar.zst" \
        --hostname "$HN" \
        --rootfs "$STORAGE_POOL:${var_disk}G" \
        --cores "$var_cpu" \
        --memory "$var_ram" \
        --net0 "bridge=vmbr0,name=eth0,ip=dhcp" \
        --password "" \
        --unprivileged 1
    pct start "$CT_ID"
    echo "Container built successfully."
}

# Build and install
build_container
echo "${APP} LXC Container Installation Completed Successfully!"
