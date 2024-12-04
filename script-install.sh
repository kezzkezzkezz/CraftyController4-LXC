#!/usr/bin/env bash

# Logging and spinner setup
YW=$(echo "\033[33m")
BL=$(echo "\033[36m")
RD=$(echo "\033[01;31m")
GN=$(echo "\033[1;92m")
CL=$(echo "\033[m")
CM="${GN}✓${CL}"
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
[[ -z "$CTID" ]] && exit "Failed to detect next available CTID."

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

# Check if the logical volume pve/20G exists
LV_PATH="/dev/pve/20G"
if ! lvdisplay "$LV_PATH" &>/dev/null; then
  # LV doesn't exist, create it
  msg_info "Creating logical volume pve/20G"
  lvcreate -L 20G -n 20G pve || exit "Failed to create logical volume pve/20G."
  msg_ok "Created logical volume pve/20G"
fi

# Storage validation
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

# Select storage function
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
  
  # Query all storage locations
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
      "Which storage pool would you like to use for the ${CONTENT_LABEL,,}?\n" \
      16 $(($MSG_MAX_LENGTH + 23)) 6 \
      "${MENU[@]}" 3>&1 1>&2 2>&3) || exit "Menu aborted."
    done
    printf $STORAGE
  fi
}

# Select template and container storage
TEMPLATE_STORAGE=$(select_storage template) || exit 1
msg_ok "Using ${BL}$TEMPLATE_STORAGE${CL} ${GN}for Template Storage."

CONTAINER_STORAGE=$(select_storage container) || exit 1
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

# Build the container
msg_info "Creating LXC Container"
if ! pct create "$CTID" "${TEMPLATE_STORAGE}:vztmpl/${TEMPLATE}" -rootfs "${CONTAINER_STORAGE}:20G" -cores 2 -memory 2048 \
-net0 bridge=vmbr0,name=eth0,ip=dhcp --password "$(openssl rand -base64 12)" --unprivileged 1 >/dev/null; then
    echo "ERROR: Failed to create container with CTID ${CTID}."
    exit 1
fi
msg_ok "LXC Container ${BL}$CTID${CL} ${GN}was successfully created."
