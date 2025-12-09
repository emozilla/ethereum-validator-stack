#!/bin/bash

# --- start.sh ---
# Starts ETH2 Node Docker Compose stack.
set -e

echo "2. Starting all services..."

# Source the environment variables
if [ -f .env ]; then
    source .env
else
    echo "ERROR: .env file not found. Please create it from .env.sample."
    exit 1
fi

docker compose up -d

echo ""
echo "ETH2 stack started in detached mode."
echo "Health check: ./check-health.py"
echo "View dashboard: http://localhost:3000 (admin/${GRAFANA_PASSWORD})"