#!/bin/bash

# Crafty Controller 4 LXC One-Line Installation Script

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to log messages
log() {
    echo -e "${GREEN}[CRAFTY INSTALLER]${NC} $1"
}

# Function to log warnings
warn() {
    echo -e "${YELLOW}[CRAFTY INSTALLER - WARNING]${NC} $1"
}

# Function to log errors
error() {
    echo -e "${RED}[CRAFTY INSTALLER - ERROR]${NC} $1"
    exit 1
}

# Ensure script is run as root
if [[ $EUID -ne 0 ]]; then
   error "This script must be run as root. Use sudo or run as root."
fi

# Main installation function
install_crafty() {
    # Update system
    log "Updating system packages..."
    apt-get update || error "Failed to update package lists"
    apt-get upgrade -y || warn "System upgrade encountered issues"

    # Install core dependencies
    log "Installing required dependencies..."
    apt-get install -y \
        git \
        curl \
        wget \
        unzip \
        python3 \
        python3-pip \
        python3-venv \
        python3-dev \
        build-essential \
        || error "Failed to install dependencies"

    # Create crafty user and directory
    log "Setting up Crafty user and installation directory..."
    useradd -m -s /bin/bash crafty 2>/dev/null
    mkdir -p /opt/crafty
    chown -R crafty:crafty /opt/crafty

    # Perform installation as crafty user
    sudo -u crafty bash << EOF
    cd /opt/crafty

    # Create and activate virtual environment
    python3 -m venv crafty-env
    source crafty-env/bin/activate

    # Clone Crafty Controller
    git clone https://gitlab.com/crafty-controller/crafty-4.git .

    # Install Python dependencies
    pip install --upgrade pip
    pip install -r requirements.txt

    # Deactivate virtual environment
    deactivate
EOF

    # Create systemd service
    log "Creating Crafty systemd service..."
    cat << SYSTEMD > /etc/systemd/system/crafty.service
[Unit]
Description=Crafty Controller 4
After=network.target

[Service]
Type=simple
User=crafty
Group=crafty
WorkingDirectory=/opt/crafty
ExecStart=/opt/crafty/crafty-env/bin/python3 /opt/crafty/crafty/crafty.py
Restart=on-failure

[Install]
WantedBy=multi-user.target
SYSTEMD

    # Reload and start service
    systemctl daemon-reload
    systemctl enable crafty.service
    systemctl start crafty.service

    # Configure firewall if UFW is available
    if command -v ufw &> /dev/null; then
        log "Configuring UFW firewall..."
        ufw allow 8443/tcp
    fi

    # Final success message
    echo -e "\n${GREEN}✔ Crafty Controller 4 Installation Complete!${NC}"
    echo -e "${YELLOW}Web Interface: https://[SERVER_IP]:8443${NC}"
    echo -e "${RED}IMPORTANT: Change default credentials immediately after first login!${NC}"
}

# Run the installation
install_crafty
