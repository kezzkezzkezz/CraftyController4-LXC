#!/usr/bin/env bash

# Logging and spinner setup
YW='\033[33m'
BL='\033[36m'
RD='\033[01;31m'
GN='\033[1;92m'
CL='\033[m'
CM='${GN}✓${CL}'
CROSS="${RD}✗${CL}"
BFR="\\r\\033[K"
HOLD=" "

set -Eeuo pipefail
trap 'error_handler $LINENO "$BASH_COMMAND"' ERR

SPINNER_PID=""

# The spinner function should now check if the process is running
function spinner() {
    local chars="/-\|"
    local spin_i=0
    printf "\e[?25l"
    while true; do
        printf "\r \e[36m%s\e[0m" "${chars:spin_i++%${#chars}:1}"
        sleep 0.1
    done
}

# Update function for msg_info
function msg_info() {
  local msg="$1"
  echo -ne " ${HOLD} ${YW}${msg}   "
  spinner &
  SPINNER_PID=$!
}

# Update the error handler to stop the spinner correctly
function error_handler() {
    if [ -n "$SPINNER_PID" ] && ps -p $SPINNER_PID > /dev/null; then kill $SPINNER_PID > /dev/null; fi
    printf "\e[?25h"
    local exit_code="$?"
    local line_number="$1"
    local command="$2"
    local error_message="${RD}[ERROR]${CL} in line ${RD}$line_number${CL}: exit code ${RD}$exit_code${CL}: while executing command ${YW}$command${CL}"
    echo -e "\n$error_message\n"
}

function msg_ok() {
  if [ -n "$SPINNER_PID" ] && ps -p $SPINNER_PID > /dev/null; then kill $SPINNER_PID > /dev/null; fi
  printf "\e[?25h"
  local msg="$1"
  echo -e "${BFR} ${CM} ${GN}${msg}${CL}"
}

function msg_error() {
  if [ -n "$SPINNER_PID" ] && ps -p $SPINNER_PID > /dev/null; then kill $SPINNER_PID > /dev/null; fi
  printf "\e[?25h"
  local msg="$1"
  echo -e "${BFR} ${CROSS} ${RD}${msg}${CL}"
}

# Auto-detect CTID
CTID=$(pvesh get /cluster/nextid)
[[ -z "$CTID" ]] && { echo "Failed to detect next available CTID."; exit 1; }

msg_ok "Using CTID: ${BL}$CTID${CL}"

# Set the PCT_OSTYPE directly
PCT_OSTYPE="debian-12-standard_12.7-1"
msg_ok "Using PCT_OSTYPE: ${BL}$PCT_OSTYPE${CL}"

# Validate required variables
[[ "${CTID:-}" ]] || exit "You need to set 'CTID' variable."
[[ "${PCT_OSTYPE:-}" ]] || exit "You need to set 'PCT_OSTYPE' variable."

# Validate ID
[ "$CTID" -ge "100" ] || exit "ID cannot be less than 100."

# Check if ID is already in use
if pct status $CTID &>/dev/null; then
  msg_error "ID '$CTID' is already in use."
  unset CTID
  exit "Cannot use ID that is already in use."
fi

# Ensure local-lvm storage pool is available
if ! pvesm status | grep -q "local-lvm"; then
  msg_error "local-lvm storage pool is not available."
  exit 1
fi
msg_ok "Using local-lvm as storage."

# Select storage and template (assuming local-lvm is selected directly)
TEMPLATE_STORAGE="local"
msg_ok "Using ${BL}$TEMPLATE_STORAGE${CL} ${GN}for Template Storage."

CONTAINER_STORAGE="local-lvm"
msg_ok "Using ${BL}$CONTAINER_STORAGE${CL} ${GN}for Container Storage."

# Update LXC template list
msg_info "Updating LXC Template List"
pveam update >/dev/null
msg_ok "Updated LXC Template List"

# Construct LXC template search string
TEMPLATE_SEARCH=${PCT_OSTYPE}${PCT_OSVERSION:+-$PCT_OSVERSION}
msg_info "Searching for templates matching: $TEMPLATE_SEARCH"

# Fetch available templates
mapfile -t TEMPLATES < <(pveam available -section system | sed -n "s/.*\($TEMPLATE_SEARCH.*\)/\1/p" | sort -t - -k 2 -V)

if [ ${#TEMPLATES[@]} -eq 0 ]; then
    echo "ERROR: No templates found for search '${TEMPLATE_SEARCH}'. Check PCT_OSTYPE (${PCT_OSTYPE}) and PCT_OSVERSION (${PCT_OSVERSION})."
    exit 1
fi

# Use the first template in the list
TEMPLATE=${TEMPLATES[0]:-}
if [ -z "$TEMPLATE" ]; then
    echo "ERROR: TEMPLATE variable is unbound. No valid templates available."
    exit 1
fi
msg_ok "Selected template: ${BL}${TEMPLATE}${CL}"

# Download LXC template if not already present
if ! pveam list "$TEMPLATE_STORAGE" | grep -q "$TEMPLATE"; then
    msg_info "Downloading LXC Template: $TEMPLATE"
    if ! pveam download "$TEMPLATE_STORAGE" "$TEMPLATE" >/dev/null; then
        echo "ERROR: Failed to download LXC template '$TEMPLATE'."
        exit 1
    fi
    msg_ok "Downloaded LXC Template"
else
    msg_ok "Template already exists in storage."
fi

# Create Logical Volume for container (if not already created)
msg_info "Creating Logical Volume for container disk"
lvcreate -V 20G --name "vm-${CTID}-disk-0" --thin pve/data
if [ $? -ne 0 ]; then
    msg_error "Failed to create logical volume 'vm-${CTID}-disk-0'."
    exit 1
fi
msg_ok "Logical volume 'vm-${CTID}-disk-0' created."

# Create LXC container on local-lvm
msg_info "Creating LXC Container"
pct create "$CTID" "${TEMPLATE_STORAGE}:vztmpl/${TEMPLATE}" -rootfs "local-lvm:vm-${CTID}-disk-0" -cores 4 -memory 2048 -net0 bridge=vmbr0,name=eth0,ip=dhcp --unprivileged 1
if [ $? -ne 0 ]; then
    msg_error "Failed to create container with CTID ${CTID}."
    exit 1
fi
msg_ok "LXC Container ${BL}$CTID${CL} ${GN}was successfully created."
