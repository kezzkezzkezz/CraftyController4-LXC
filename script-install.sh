#!/usr/bin/env bash
# Crafty LXC Container Installation Script

# Logging function
log_error() {
    echo "[ERROR] $1" >&2
}

log_info() {
    echo "[INFO] $1"
}

# Test if required variables are set
[[ "${CTID:-}" ]] || exit "You need to set 'CTID' variable."
[[ "${PCT_OSTYPE:-}" ]] || exit "You need to set 'PCT_OSTYPE' variable."

# Test if ID is valid
[ "$CTID" -ge "100" ] || exit "ID cannot be less than 100."

# Test if ID is in use
if pct status $CTID &>/dev/null; then
  echo -e "ID '$CTID' is already in use."
  unset CTID
  exit "Cannot use ID that is already in use."
fi

# Configuration variables
APP="Crafty"
VAR_DISK="20"  # Disk size in GB
VAR_CPU="2"    # CPU cores
VAR_RAM="2048" # RAM size in MB

# Function to list storage pools and select one
select_storage_pool() {
    local POOLS
    # Gather available storage pools
    POOLS=$(pvesm status | awk 'NR>1 {print $1}')
    
    # Check if pools are found
    if [[ -z "$POOLS" ]]; then
        log_error "No storage pools found. Please ensure your Proxmox VE storage is configured."
        exit 1
    fi
    
    # If only one pool exists, use it
    if [[ $(echo "$POOLS" | wc -l) -eq 1 ]]; then
        echo "$POOLS"
        return 0
    fi
    
    # If multiple pools, use dialog or whiptail
    if command -v whiptail &>/dev/null; then
        SELECTED_POOL=$(echo "$POOLS" | whiptail --title "Select Storage Pool" --menu \
            "Choose a storage pool for the container:" 20 78 10 \
            $(echo "$POOLS" | awk '{print NR " " $0}') 3>&1 1>&2 2>&3)
    elif command -v dialog &>/dev/null; then
        SELECTED_POOL=$(echo "$POOLS" | dialog --title "Select Storage Pool" --menu \
            "Choose a storage pool for the container:" 20 78 10 \
            $(echo "$POOLS" | awk '{print NR " " $0}') 2>&1 1>&3)
    else
        log_error "Neither whiptail nor dialog found. Please manually specify a storage pool."
        exit 1
    fi
    
    # Exit if canceled
    if [[ -z "$SELECTED_POOL" ]]; then
        log_error "Storage pool selection canceled."
        exit 1
    fi
    
    # Extract the selected storage pool
    echo "$POOLS" | awk "NR==$SELECTED_POOL"
}

# Ensure script is run as root
if [[ $EUID -ne 0 ]]; then
   log_error "This script must be run as root on a Proxmox VE host"
   exit 1
fi

# Get the selected storage pool
STORAGE_POOL=$(select_storage_pool)
log_info "Selected storage pool: $STORAGE_POOL"

# Find an available container ID
CT_ID=$(find_next_available_ctid)
log_info "Using container ID: $CT_ID"

# Ensure storage pool is valid and exists
if ! pvesm status | grep -q "^$STORAGE_POOL "; then
    log_error "Selected storage pool does not exist or is invalid!"
    exit 1
fi

# Function to build the container
build_container() {
    local HN="crafty-container"
    
    # Generate a random, secure password
    PASSWORD=$(openssl rand -base64 12)
    
    # Create the container
    pct create "$CT_ID" "$STORAGE_POOL:debian-12-standard_12.7-1_amd64.tar.zst" \
        --hostname "$HN" \
        --rootfs "$STORAGE_POOL:${VAR_DISK}G" \
        --cores "$VAR_CPU" \
        --memory "$VAR_RAM" \
        --net0 "bridge=vmbr0,name=eth0,ip=dhcp" \
        --password "$PASSWORD" \
        --unprivileged 1
    
    # Check if container creation was successful
    if [ $? -ne 0 ]; then
        log_error "Failed to create container"
        exit 1
    fi
    
    # Start the container
    pct start "$CT_ID"
    
    # Check if container start was successful
    if [ $? -ne 0 ]; then
        log_error "Failed to start container"
        exit 1
    fi
    
    log_info "Container root password: $PASSWORD"
    log_info "Please change this password after first login!"
}

# Build and install
build_container

log_info "${APP} LXC Container Installation Completed Successfully!"
