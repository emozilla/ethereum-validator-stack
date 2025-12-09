#!/bin/bash

# Check the status of the validator stack
# This script checks both systemd service status and Docker container status

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "=== Validator Stack Status ==="
echo ""

# Check systemd service status
echo "Systemd Service Status:"
if systemctl is-active --quiet validator-stack 2>/dev/null; then
    echo -e "${GREEN}✓ Service is active${NC}"
    systemctl status validator-stack --no-pager -l | head -n 5
else
    echo -e "${RED}✗ Service is not active${NC}"
    systemctl status validator-stack --no-pager -l | head -n 5
fi

echo ""
echo "Docker Container Status:"

# Check if we're in the validator directory
if [ ! -f "docker-compose.yaml" ]; then
    echo -e "${RED}Error: docker-compose.yaml not found. Run this script from the validator directory.${NC}"
    exit 1
fi

# Check Docker containers
if command -v docker &> /dev/null; then
    docker compose ps
else
    echo -e "${RED}Error: docker command not found${NC}"
    exit 1
fi

echo ""
echo "=== Health Check ==="
if [ -f "check-health.sh" ]; then
    ./check-health.sh
else
    echo "Health check script not found"
fi

