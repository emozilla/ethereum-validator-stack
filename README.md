# Ethereum Validator Stack

A production-ready Ethereum validator infrastructure stack using Docker Compose. This stack includes an execution client (Geth), consensus client (Lighthouse), validator client, Web3Signer for remote signing, and a complete monitoring solution with Prometheus and Grafana.

## Table of Contents

- [Architecture](#architecture)
- [Components](#components)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Configuration](#configuration)
- [Deployment](#deployment)
- [Usage](#usage)
- [Monitoring](#monitoring)
- [Health Checks](#health-checks)
- [Troubleshooting](#troubleshooting)
- [Security Considerations](#security-considerations)

## Architecture

### System Overview

This validator stack implements a complete Ethereum 2.0 validator infrastructure with the following architecture:

```
┌─────────────────────────────────────────────────────────────────┐
│                     Ethereum Validator Stack                     │
└─────────────────────────────────────────────────────────────────┘

┌──────────────┐      ┌──────────────┐      ┌──────────────┐
│   Geth       │◄────►│  Lighthouse  │◄────►│  Lighthouse  │
│  Execution   │ JWT  │  Beacon Node │      │   Validator  │
│   Client     │      │  (Consensus) │      │    Client    │
└──────────────┘      └──────────────┘      └──────┬───────┘
                                                    │
                                                    │ HTTP
                                                    ▼
                                            ┌──────────────┐
                                            │  Web3Signer  │
                                            │  (Signing)   │
                                            └──────┬───────┘
                                                   │
                                                   │ JDBC
                                                   ▼
                                            ┌──────────────┐
                                            │  PostgreSQL  │
                                            │   Database   │
                                            └──────────────┘

┌──────────────┐      ┌──────────────┐      ┌──────────────┐
│  Prometheus  │◄─────│  Node        │      │   Grafana    │
│  (Metrics)   │      │  Exporter    │      │  (Dashboard) │
└──────────────┘      └──────────────┘      └──────────────┘
```

### Network Architecture

All services run in a Docker bridge network (`eth-net`) with the following exposed ports:

| Service | Port | Purpose |
|---------|------|---------|
| Geth | 8545 | HTTP RPC API |
| Geth | 30303 | P2P (TCP/UDP) |
| Lighthouse BN | 5052 | Beacon Node HTTP API |
| Lighthouse BN | 5054 | Metrics |
| Lighthouse VC | 5062 | Validator Client HTTP API |
| Lighthouse VC | 5064 | Metrics |
| Web3Signer | 9000 | HTTP API |
| Web3Signer | 9001 | Metrics |
| PostgreSQL | 5432 | Database (internal) |
| Prometheus | 9090 | Metrics UI |
| Grafana | 3000 | Dashboard UI |
| Node Exporter | 9100 | System Metrics |

## Components

### 1. Execution Layer (Geth)
- **Image**: `ethereum/client-go`
- **Role**: Execution client handling transactions and state
- **Features**:
  - Engine API for consensus layer communication
  - HTTP RPC for external access
  - Metrics endpoint for monitoring
  - JWT authentication with consensus layer

### 2. Consensus Layer (Lighthouse Beacon Node)
- **Image**: `sigp/lighthouse`
- **Role**: Beacon node managing consensus state
- **Features**:
  - Checkpoint sync for fast initialization
  - Validator monitoring
  - JSON logging
  - RESTful API for validator client

### 3. Validator Client (Lighthouse)
- **Image**: `sigp/lighthouse`
- **Role**: Manages validator duties (attestations, proposals)
- **Features**:
  - Remote signing via Web3Signer
  - Local slashing protection
  - Fee recipient configuration
  - HTTP API for monitoring

### 4. Web3Signer
- **Image**: `consensys/web3signer`
- **Role**: Remote signing service for validator keys
- **Features**:
  - Keystore management
  - PostgreSQL slashing protection
  - Health checks
  - Metrics endpoint

### 5. PostgreSQL Database
- **Image**: `postgres`
- **Role**: Stores Web3Signer slashing protection data
- **Features**:
  - Automatic schema migrations
  - Health checks
  - Persistent storage

### 6. Monitoring Stack
- **Prometheus**: Metrics collection and storage
- **Grafana**: Visualization dashboards
- **Node Exporter**: System-level metrics

## Prerequisites

Before deploying this stack, ensure you have:

1. **Docker & Docker Compose**
   ```bash
   docker --version
   docker compose version
   ```

2. **Python 3** (for health checks)
   ```bash
   python3 --version
   ```

3. **Validator Keystore Files**
   - Encrypted keystore file (`.json`)
   - Password file (`.txt`)
   - Both files must be placed in `data/web3signer/`

4. **Network Connectivity**
   - Internet access for checkpoint sync
   - P2P ports open (30303) for execution client

5. **System Resources**
   - Minimum 32GB RAM
   - 500GB+ SSD storage
   - Stable internet connection

## Installation

### 1. Clone the Repository

```bash
git clone <repository-url>
cd validator
```

### 2. Create Environment File

Create a `.env` file in the project root. You can use the following template:

```bash
# Network Configuration
NETWORK_NAME=hoodi
EXECUTION_CLIENT_NETWORK_FLAG=--hoodi

# Docker Image Versions
GETH_VERSION=latest
LIGHTHOUSE_VERSION=latest
WEB3SIGNER_VERSION=latest
POSTGRES_VERSION=15
PROMETHEUS_VERSION=latest
GRAFANA_VERSION=latest
NODE_EXPORTER_VERSION=latest

# Validator Configuration
V_PUB_KEY=your_validator_public_key_here
FEE_RECIPIENT=0xYourFeeRecipientAddress
CHECKPOINT_SYNC_URL=https://checkpoint-sync-url.example.com

# Database Configuration
DB_PASSWORD=your_secure_database_password

# Grafana Configuration
GRAFANA_PASSWORD=your_grafana_admin_password

# Health Check Configuration
VALIDATOR_INDEX=your_validator_index
```

**Important**: Replace all placeholder values with your actual configuration.

### 3. Place Keystore Files

Place your validator keystore files in the `data/web3signer/` directory:

```bash
# Example structure:
data/web3signer/
├── keystore-m_12381_3600_0_0_0-1234567890.json
└── keystore-m_12381_3600_0_0_0-1234567890.txt
```

The password file should contain the plaintext password for the keystore.

## Configuration

### Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `NETWORK_NAME` | Ethereum network name | `mainnet`, `goerli`, `sepolia` |
| `EXECUTION_CLIENT_NETWORK_FLAG` | Geth network flag | `--mainnet`, `--goerli`, `--sepolia` |
| `GETH_VERSION` | Geth Docker image tag | `latest`, `v1.13.0` |
| `LIGHTHOUSE_VERSION` | Lighthouse Docker image tag | `latest`, `v5.0.0` |
| `WEB3SIGNER_VERSION` | Web3Signer Docker image tag | `latest`, `v23.10.0` |
| `POSTGRES_VERSION` | PostgreSQL Docker image tag | `15`, `15-alpine` |
| `PROMETHEUS_VERSION` | Prometheus Docker image tag | `latest`, `v2.48.0` |
| `GRAFANA_VERSION` | Grafana Docker image tag | `latest`, `v10.2.0` |
| `NODE_EXPORTER_VERSION` | Node Exporter Docker image tag | `latest`, `v1.6.1` |
| `V_PUB_KEY` | Validator public key (without 0x prefix) | `abc123...` |
| `FEE_RECIPIENT` | Ethereum address for MEV/block rewards | `0x1234...` |
| `CHECKPOINT_SYNC_URL` | Checkpoint sync endpoint URL | `https://sync-mainnet.beaconcha.in` |
| `DB_PASSWORD` | PostgreSQL database password | Strong password |
| `GRAFANA_PASSWORD` | Grafana admin password | Strong password |
| `VALIDATOR_INDEX` | Your validator index (for health checks) | `12345` |

### Network-Specific Configuration

#### Mainnet
```bash
NETWORK_NAME=mainnet
EXECUTION_CLIENT_NETWORK_FLAG=--mainnet
CHECKPOINT_SYNC_URL=https://sync-mainnet.beaconcha.in
```

#### Hoodi Testnet
```bash
NETWORK_NAME=hoodi
EXECUTION_CLIENT_NETWORK_FLAG=--hoodi
CHECKPOINT_SYNC_URL=https://hoodi.beaconstate.info
```

#### Sepolia Testnet
```bash
NETWORK_NAME=sepolia
EXECUTION_CLIENT_NETWORK_FLAG=--sepolia
CHECKPOINT_SYNC_URL=https://sync-sepolia.beaconcha.in
```

## Deployment

### Step 1: Provision Infrastructure

Run the provisioning script to set up directories, generate secrets, and extract database migrations:

```bash
chmod +x provision.sh
./provision.sh
```

This script will:
- Create necessary directories
- Generate JWT secret (`jwtsecret.hex`)
- Extract database migration files from Web3Signer image
- Set proper permissions

**Note**: The provisioning script requires Docker to be running and may require `sudo` for permission changes.

### Step 2: Verify Keystore Files

Ensure your keystore files are in place:

```bash
ls -la data/web3signer/
```

You should see:
- At least one `.json` keystore file
- Corresponding `.txt` password file(s)

### Step 3: Start the Stack

Start all services:

```bash
chmod +x start-validator.sh
./start-validator.sh
```

### Step 4: Verify Services

Check that all services are running:

```bash
docker compose ps
```

All services should show `Up` status. The initial sync may take several hours depending on network and hardware.

## Usage

### Starting Services

```bash
./start-validator.sh
# or
docker compose up -d
```

### Stopping Services

```bash
docker compose down
```

### Viewing Logs

View logs for a specific service:

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f consensus
docker compose logs -f validator
docker compose logs -f web3signer
```

### Restarting Services

```bash
# Restart all services
docker compose restart

# Restart specific service
docker compose restart validator
```

### Updating Services

1. Update image versions in `.env`
2. Pull new images:
   ```bash
   docker compose pull
   ```
3. Restart services:
   ```bash
   docker compose up -d
   ```

### Systemd Service (Production)

For production deployments, you can run the validator stack as a systemd service for automatic startup, proper service management, and centralized logging.

**Installation**:
```bash
# Make installation script executable
chmod +x install-systemd.sh

# Install the service (requires sudo)
sudo ./install-systemd.sh
```

**Service Management**:
```bash
# Start the validator stack
sudo systemctl start validator-stack

# Stop the validator stack
sudo systemctl stop validator-stack

# Restart the validator stack
sudo systemctl restart validator-stack

# Check service status
sudo systemctl status validator-stack

# View logs
sudo journalctl -u validator-stack -f

# Enable service to start on boot
sudo systemctl enable validator-stack
```

**Benefits**:
- Automatic startup on system boot
- Proper service dependencies
- Centralized logging via systemd journal
- Standard Linux service management
- Integration with system monitoring tools

For more details, see the [Production Improvement Notes](PRODUCTION_NOTES.md#5-systemd-service-management).

## Monitoring

### Grafana Dashboard

Access the Grafana dashboard at:
- **URL**: http://localhost:3000
- **Username**: `admin`
- **Password**: Value from `GRAFANA_PASSWORD` in `.env`

The dashboard includes:
- Node sync status
- Validator performance metrics
- Attestation success rates
- System resource usage
- Network statistics

### Prometheus

Access Prometheus at:
- **URL**: http://localhost:9090

Query metrics directly or explore available metrics.

### Health Checks

Run the health check script to verify validator status:

```bash
chmod +x check-health.sh
./check-health.sh
```

Or directly:

```bash
python3 fetch.py
```

The health check verifies:
- ✅ Geth sync status
- ✅ Beacon node sync status
- ✅ Validator status and duties

**Note**: Requires `VALIDATOR_INDEX` to be set in `.env`.

## Health Checks

### Service Health Checks

The stack includes built-in health checks:

- **Web3Signer**: HTTP health check on port 9000
- **PostgreSQL**: Database readiness check

### Manual Health Verification

1. **Check Geth Sync**:
   ```bash
   curl -X POST http://localhost:8545 \
     -H "Content-Type: application/json" \
     -d '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}'
   ```

2. **Check Beacon Node**:
   ```bash
   curl http://localhost:5052/eth/v1/node/health
   ```

3. **Check Validator Client**:
   ```bash
   curl http://localhost:5062/lighthouse/health
   ```

4. **Check Web3Signer**:
   ```bash
   curl http://localhost:9000/healthcheck
   ```

## Troubleshooting

### Services Not Starting

1. **Check Docker logs**:
   ```bash
   docker compose logs
   ```

2. **Verify environment variables**:
   ```bash
   cat .env
   ```

3. **Check port conflicts**:
   ```bash
   netstat -tulpn | grep -E '8545|5052|3000|9090'
   ```

### Validator Not Attesting

1. **Check validator status**:
   ```bash
   ./check-health.sh
   ```

2. **Verify keystore files**:
   ```bash
   ls -la data/web3signer/
   ```

3. **Check Web3Signer logs**:
   ```bash
   docker compose logs web3signer
   ```

4. **Verify validator is active**:
   - Check Grafana dashboard
   - Verify validator index in beacon explorer

### Database Issues

1. **Check PostgreSQL logs**:
   ```bash
   docker compose logs db
   ```

2. **Verify migrations**:
   ```bash
   ls -la config/db/
   ```

3. **Reset database** (⚠️ **WARNING**: This will delete slashing protection data):
   ```bash
   docker compose down -v
   docker volume rm validator_web3signer_db
   ./provision.sh
   docker compose up -d
   ```

### Sync Issues

1. **Check checkpoint sync URL**:
   - Verify `CHECKPOINT_SYNC_URL` is correct
   - Test connectivity: `curl $CHECKPOINT_SYNC_URL`

2. **Monitor sync progress**:
   - Check Grafana dashboard
   - Review beacon node logs

3. **Restart sync** (if needed):
   ```bash
   docker compose restart consensus
   ```

### Permission Issues

If you encounter permission errors:

```bash
# Fix ownership
sudo chown -R $USER:$USER config/ data/

# Fix permissions
chmod -R 755 config/ data/
```

## Security Considerations

### 1. Secrets Management

- **Never commit** `.env` file to version control
- **Never commit** `jwtsecret.hex` to version control
- **Never commit** keystore files or passwords
- Use strong, unique passwords for database and Grafana

### 2. Network Security

- Consider using a firewall to restrict external access
- Only expose necessary ports
- Use VPN or SSH tunnel for remote access to Grafana

### 3. Keystore Security

- Keystore files are mounted read-only in Web3Signer
- Store keystore files securely
- Use strong passwords for keystores
- Consider hardware security modules (HSM) for production

### 4. Slashing Protection

- **Critical**: Slashing protection data is stored in PostgreSQL
- **Backup regularly**: Database volumes contain critical slashing protection data
- **Never run multiple validators** with the same keys simultaneously

### 5. System Security

- Keep Docker and images updated
- Use specific image versions in production
- Regularly update system packages
- Monitor for security advisories

### 6. Backup Strategy

**Critical data to backup**:
- PostgreSQL database volume (`web3igner_db`)
- Keystore files (`data/web3signer/`)
- JWT secret (`jwtsecret.hex`)
- Environment file (`.env`)

**Backup commands**:
```bash
# Backup database
docker compose exec db pg_dump -U web3signer web3signer > backup.sql

# Backup keystores
tar -czf keystores-backup.tar.gz data/web3signer/

# Backup configuration
cp .env .env.backup
cp jwtsecret.hex jwtsecret.hex.backup
```


## Additional Resources

- [Lighthouse Documentation](https://lighthouse-book.sigmaprime.io/)
- [Web3Signer Documentation](https://docs.web3signer.consensys.io/)
- [Ethereum Staking Guide](https://ethereum.org/en/staking/)
- **[Production Improvement Notes](PRODUCTION_NOTES.md)** - Comprehensive guide for production deployments, security hardening, monitoring, and operational best practices

## Support

For issues or questions:
1. Check the troubleshooting section
2. Review service logs
3. Consult official documentation for each component
4. Review [Production Improvement Notes](PRODUCTION_NOTES.md) for production best practices

## License

MIT License
