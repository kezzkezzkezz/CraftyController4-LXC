#!/bin/bash

# Display messages
msg_info() {
  echo "[INFO] $1"
}

msg_error() {
  echo "[ERROR] $1"
  exit 1
}

# This checks for the presence of valid Container Storage and Template Storage locations
msg_info "Validating Storage"
VALIDCT=$(pvesm status -content rootdir | awk 'NR>1')
if [ -z "$VALIDCT" ]; then
  msg_error "Unable to detect a valid Container Storage location."
  exit 1
fi

VALIDTMP=$(pvesm status -content vztmpl | awk 'NR>1')
if [ -z "$VALIDTMP" ]; then
  msg_error "Unable to detect a valid Template Storage location."
  exit 1
fi

# This function is used to select the storage class and determine the corresponding storage content type and label.
function select_storage() {
  local CLASS=$1
  local CONTENT
  local CONTENT_LABEL
  case $CLASS in
  container)
    CONTENT='rootdir'
    CONTENT_LABEL='Container'
    ;;
  template)
    CONTENT='vztmpl'
    CONTENT_LABEL='Container template'
    ;;
  *) false || exit "Invalid storage class." ;;
  esac
  
  # This Queries all storage locations
  local -a MENU
  while read -r line; do
    local TAG=$(echo $line | awk '{print $1}')
    local TYPE=$(echo $line | awk '{printf "%-10s", $2}')
    local FREE=$(echo $line | numfmt --field 4-6 --from-unit=K --to=iec --format %.2f | awk '{printf( "%9sB", $6)}')
    local ITEM="  Type: $TYPE Free: $FREE "
    local OFFSET=2
    if [[ $((${#ITEM} + $OFFSET)) -gt ${MSG_MAX_LENGTH:-} ]]; then
      local MSG_MAX_LENGTH=$((${#ITEM} + $OFFSET))
    fi
    MENU+=("$TAG" "$ITEM" "OFF")
  done < <(pvesm status -content $CONTENT | awk 'NR>1')
  
  # Select storage location
  if [ $((${#MENU[@]}/3)) -eq 1 ]; then
    printf ${MENU[0]}
  else
    local STORAGE
    while [ -z "${STORAGE:+x}" ]; do
      STORAGE=$(whiptail --backtitle "Proxmox VE Helper Scripts" --title "Storage Pools" --radiolist \
      "Which storage pool you would like to use for the ${CONTENT_LABEL,,}?\nTo make a selection, use the Spacebar.\n" \
      16 $(($MSG_MAX_LENGTH + 23)) 6 \
      "${MENU[@]}" 3>&1 1>&2 2>&3) || exit "Menu aborted."
    done
    printf $STORAGE
  fi
}

# Select storage for containers and templates
CONTAINER_STORAGE=$(select_storage container)
TEMPLATE_STORAGE=$(select_storage template)

# Output the selected storage for confirmation
msg_info "Using Container Storage: $CONTAINER_STORAGE"
msg_info "Using Template Storage: $TEMPLATE_STORAGE"

# Container setup variables
CTID=125
TEMPLATE="debian-12-standard_12.7-1_amd64.tar.zst"

msg_info "Creating LXC Container $CTID using template $TEMPLATE"
# Create the container using the selected storage locations
pct create "$CTID" "${TEMPLATE_STORAGE}:vztmpl/${TEMPLATE}" -rootfs "$CONTAINER_STORAGE:vm-${CTID}-disk-0" -cores 4 -memory 2048 -net0 bridge=vmbr0,name=eth0,ip=dhcp --unprivileged 1

# Wait for the container to start
msg_info "Waiting for the container to start..."
pct start $CTID
sleep 5  # Allow the container some time to start

# Install Crafty Controller in the container
msg_info "Installing Crafty Controller in the container"

# Define the install script URL
INSTALL_URL="https://raw.githubusercontent.com/kezzkezzkezz/CraftyController4-LXC/main/script-install.sh"

# Execute the installation script inside the container
pct exec "$CTID" -- bash -c "$(wget -qO- $INSTALL_URL)"

# Confirmation message
msg_info "Crafty Controller installation complete in container $CTID."

