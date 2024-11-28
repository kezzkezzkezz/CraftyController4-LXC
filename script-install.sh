#!/bin/bash

# Crafty Controller 4 Installation Script for LXC
# Tested on Debian/Ubuntu-based systems

# Ensure script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

# Update system packages
echo "Updating system packages..."
apt-get update && apt-get upgrade -y

# Install required dependencies
echo "Installing required dependencies..."
apt-get install -y \
    git \
    python3 \
    python3-pip \
    python3-venv \
    wget \
    curl \
    unzip \
    software-properties-common

# Create Crafty user and directory
echo "Creating Crafty user and installation directory..."
useradd -m -s /bin/bash crafty
mkdir -p /opt/crafty
chown -R crafty:crafty /opt/crafty

# Switch to crafty user for installation
sudo -u crafty bash << EOF

# Change to Crafty installation directory
cd /opt/crafty

# Create Python virtual environment
python3 -m venv crafty-env

# Activate virtual environment
source crafty-env/bin/activate

# Clone Crafty Controller 4
git clone https://gitlab.com/crafty-controller/crafty-4.git .

# Install Python dependencies
pip install -r requirements.txt

# Deactivate virtual environment
deactivate
EOF

# Set up systemd service
echo "Creating systemd service for Crafty Controller..."
cat << SYSTEMD > /etc/systemd/system/crafty.service
[Unit]
Description=Crafty Controller 4
After=network.target

[Service]
Type=simple
User=crafty
WorkingDirectory=/opt/crafty
ExecStart=/opt/crafty/crafty-env/bin/python3 /opt/crafty/crafty/crafty.py
Restart=on-failure

[Install]
WantedBy=multi-user.target
SYSTEMD

# Reload systemd, enable and start Crafty service
systemctl daemon-reload
systemctl enable crafty.service
systemctl start crafty.service

# Open firewall ports (if UFW is installed)
# Crafty typically uses port 8443 for web interface
echo "Configuring firewall (if available)..."
if command -v ufw &> /dev/null; then
    ufw allow 8443/tcp
fi

echo "Crafty Controller 4 installation complete!"
echo "Access the web interface at https://[YOUR_IP]:8443"
echo "Default credentials will be displayed in the first-time setup"

# Recommend user to change default credentials
echo "IMPORTANT: Change default credentials after first login!"
