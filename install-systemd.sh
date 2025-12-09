#!/bin/bash

# Install systemd service for Ethereum Validator Stack
# This script installs the validator-stack.service file to systemd

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_FILE="validator-stack.service"
SYSTEMD_DIR="/etc/systemd/system"
SERVICE_NAME="validator-stack.service"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "Installing systemd service for Ethereum Validator Stack..."

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Error: This script must be run as root (use sudo)${NC}"
    exit 1
fi

# Check if service file exists
if [ ! -f "$SCRIPT_DIR/$SERVICE_FILE" ]; then
    echo -e "${RED}Error: Service file not found: $SCRIPT_DIR/$SERVICE_FILE${NC}"
    exit 1
fi

# Get the actual validator directory path
VALIDATOR_DIR=$(readlink -f "$SCRIPT_DIR")

echo -e "${YELLOW}Validator directory: $VALIDATOR_DIR${NC}"
read -p "Is this correct? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Installation cancelled."
    exit 1
fi

# Create a temporary service file with the correct path
TEMP_SERVICE=$(mktemp)
sed -e "s|WorkingDirectory=/opt/validator|WorkingDirectory=$VALIDATOR_DIR|g" \
    -e "s|ReadWritePaths=/opt/validator|ReadWritePaths=$VALIDATOR_DIR|g" \
    "$SCRIPT_DIR/$SERVICE_FILE" > "$TEMP_SERVICE"

# Copy service file to systemd directory
echo "Copying service file to $SYSTEMD_DIR..."
cp "$TEMP_SERVICE" "$SYSTEMD_DIR/$SERVICE_NAME"
rm "$TEMP_SERVICE"

# Set proper permissions
chmod 644 "$SYSTEMD_DIR/$SERVICE_NAME"

# Reload systemd
echo "Reloading systemd daemon..."
systemctl daemon-reload

# Enable the service
echo "Enabling validator-stack service..."
systemctl enable "$SERVICE_NAME"

echo -e "${GREEN}Service installed successfully!${NC}"
echo ""
echo "Service management commands:"
echo "  Start:   sudo systemctl start validator-stack"
echo "  Stop:    sudo systemctl stop validator-stack"
echo "  Status:  sudo systemctl status validator-stack"
echo "  Logs:    sudo journalctl -u validator-stack -f"
echo "  Restart: sudo systemctl restart validator-stack"
echo ""
echo -e "${YELLOW}Note: The service is enabled but not started. Start it with:${NC}"
echo "  sudo systemctl start validator-stack"

