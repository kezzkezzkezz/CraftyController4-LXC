#!/usr/bin/env bash
# Crafty LXC Container Installation Script

set -euo pipefail

# Ensure script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

# Configuration variables
APP="Crafty"
var_disk="20"  # Disk size in GB
var_cpu="2"    # CPU cores
var_ram="2048" # RAM size in MB

# Function to find a unique container ID
find_next_ct_id() {
    local start_id=101  # Start from 101 to avoid 100
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

# Ensure LVM is properly configured
configure_lvm() {
    echo "Attempting to configure LVM..."
    
    # Try to create missing device nodes
    sudo dmsetup mknodes
    
    # Rescan for volume groups
    sudo vgscan --mknodes
    
    # Activate volume groups
    sudo vgchange -ay
}

# Main script execution
main() {
    echo -e "Loading Crafty LXC Container Installation...\n"

    # Attempt to resolve LVM issues
    configure_lvm || true

    # Find container ID
    CT_ID=$(find_next_ct_id)
    echo "Using container ID: $CT_ID"

    # Select storage pool (default to local if not specified)
    STORAGE_POOL=${STORAGE_POOL:-local}

    # Verify storage pool exists
    if ! pvesm status | grep -q "^$STORAGE_POOL\b"; then
        echo "Warning: Storage pool '$STORAGE_POOL' not found. Using 'local'."
        STORAGE_POOL=local
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
        --unprivileged 1

    # Start the container
    pct start "$CT_ID"
    
    # Wait and verify container status
    sleep 5
    pct status "$CT_ID"
}

# Run main function
main
