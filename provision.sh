#!/bin/bash

# Sets up directories, generates secrets, creates configuration, and ensures correct permissions.
set -e

echo "1. Provisioning Infrastructure..."

# Source the environment variables from the .env file
if [ -f .env ]; then
    source .env
else
    echo "ERROR: .env file not found. Please create it from .env.sample."
    exit 1
fi

# Define directories (MUST MATCH your docker-compose.yaml mounts)
WEBSIGNER_KEY_DIR="./data/web3signer" 
MIGRATION_DEST_PATH="./config/db"

# --- A. Create Directories ---
echo "-> Creating necessary data and config directories..."
# Create the grafana binding dirs
mkdir -p config/grafana/datasources config/grafana/dashboards
# Create the specific directory for validator keystores
mkdir -p ${WEBSIGNER_KEY_DIR} 
# Create the directory for DB migration files
mkdir -p ${MIGRATION_DEST_PATH} 

# --- B. Create JWT Secret ---
echo "-> Creating JWT secret..."
test -f jwtsecret.hex || openssl rand -hex 32 > jwtsecret.hex

# --- C. Copy Web3Signer slashing protection db schema ---
WEBSIGNER_IMAGE="consensys/web3signer:"${WEB3SIGNER_VERSION}
MIGRATION_SOURCE_PATH="/migrations/postgresql"
TEMP_CONTAINER_NAME="web3signer-migrator-extractor"

# Check if migration files have already been extracted
if [ -z "$(ls -A ${MIGRATION_DEST_PATH})" ]; then
    echo "-> Migration files not found. Extracting from ${WEBSIGNER_IMAGE}..."
    
    # 1. Use a trap to ensure cleanup even if 'docker cp' fails
    trap "docker rm -f ${TEMP_CONTAINER_NAME} > /dev/null 2>&1" EXIT
    
    # 2. Create the container, copy files out, and remove it
    docker create --name ${TEMP_CONTAINER_NAME} ${WEBSIGNER_IMAGE}
    docker cp ${TEMP_CONTAINER_NAME}:${MIGRATION_SOURCE_PATH}/. ${MIGRATION_DEST_PATH}
    docker rm ${TEMP_CONTAINER_NAME}
    trap - EXIT
    
    echo "Migration files extracted successfully."
    # 3. CRITICAL PERMISSION FIX for extracted files
    # Files are created by root via docker cp; set ownership and permissions.
    sudo chown -R $USER:$USER ${MIGRATION_DEST_PATH}
    sudo chmod -R 755 ${MIGRATION_DEST_PATH} 
else
    echo "-> Migration files already exist in ${MIGRATION_DEST_PATH}. Skipping extraction."
fi

echo ""
echo "Provisioning Complete. Infrastructure is ready."
echo "NEXT STEPS (Required Manual Actions):"
echo "1. PLACE the encrypted keystore file (.json) and password (.txt) into the ${WEBSIGNER_KEY_DIR} directory."
echo "2. EXTERNAL: Submit the deposit data file (.json) to the Launchpad for the ${NETWORK_NAME} network."