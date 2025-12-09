#!/usr/bin/env python3
import json
import urllib.request
import urllib.error
import os
import sys

# ======================================
# CONFIGURATION
# ======================================

VALIDATOR_INDEX = os.environ.get("VALIDATOR_INDEX")

EXECUTION_RPC   = "http://localhost:8545"   # Geth / Nethermind
CONSENSUS_HTTP  = "http://localhost:5052"   # Lighthouse / Teku / Prysm

# ANSI Colors
GREEN = "\033[92m"
YELLOW = "\033[93m"
RED = "\033[91m"
BOLD = "\033[1m"
RESET = "\033[0m"

def ok(msg):   print(f"{GREEN}[OK] {msg}{RESET}")
def warn(msg): print(f"{YELLOW}[WARN] {msg}{RESET}")
def error(msg):print(f"{RED}[ERR] {msg}{RESET}")

# ======================================
# HTTP HELPERS
# ======================================

def http_get(url, timeout=5):
    try:
        req = urllib.request.Request(url)
        with urllib.request.urlopen(req, timeout=timeout) as r:
            body = r.read().decode()
            return json.loads(body) if body else {}
    except Exception as e:
        return None

def http_post(url, payload, timeout=5):
    try:
        data = json.dumps(payload).encode('utf-8')
        # Beacon Node requires strict Content-Type for POST
        headers = {"Content-Type": "application/json"}
        req = urllib.request.Request(url, data=data, headers=headers)
        with urllib.request.urlopen(req, timeout=timeout) as r:
            body = r.read().decode()
            return json.loads(body) if body else {}
    except Exception as e:
        return None

def hex_to_int(h):
    try:
        return int(h, 16)
    except:
        return None

# ======================================
# GETH CHECK
# ======================================

def check_geth_sync():
    print(f"\n{BOLD}=== Checking Execution Layer (Geth) ==={RESET}")

    # 1. Check Reachability
    try:
        urllib.request.urlopen(EXECUTION_RPC, timeout=2)
    except:
        error(f"Geth RPC unreachable at {EXECUTION_RPC}")
        return

    # 2. Check Sync Status
    # method: eth_syncing returns FALSE if synced, or a dict if syncing
    payload = {"jsonrpc":"2.0", "method":"eth_syncing", "params":[], "id":1}
    sync_data = http_post(EXECUTION_RPC, payload)

    if not sync_data:
        error("eth_syncing call failed.")
        return

    result = sync_data.get("result")

    if result is False:
        # It is synced, let's get the block number to be sure
        bn_payload = {"jsonrpc":"2.0", "method":"eth_blockNumber", "params":[], "id":1}
        bn = http_post(EXECUTION_RPC, bn_payload)
        if bn and "result" in bn:
            block = hex_to_int(bn["result"])
            ok(f"Fully synced. Block Height: {block}")
        else:
            warn("Synced, but failed to retrieve block number.")
        return

    if isinstance(result, dict):
        current = hex_to_int(result.get("currentBlock", "0x0"))
        highest = hex_to_int(result.get("highestBlock", "0x0"))
        remaining = highest - current
        warn(f"Syncing... {current} / {highest} ({remaining} blocks left)")
        return

    error("Unexpected response from eth_syncing.")

# ======================================
# BEACON NODE CHECK
# ======================================

def check_consensus_sync():
    print(f"\n{BOLD}=== Checking Consensus Layer (Beacon Node) ==={RESET}")

    # 1. Check Health Endpoint
    try:
        with urllib.request.urlopen(f"{CONSENSUS_HTTP}/eth/v1/node/health", timeout=2) as r:
            code = r.status
    except urllib.error.HTTPError as e:
        code = e.code
    except:
        error(f"Beacon node unreachable at {CONSENSUS_HTTP}")
        return

    # 2. Check Sync Status Logic
    if code == 200:
        # Double check via sync endpoint because health might be 200 while still catching up head
        sync_data = http_get(f"{CONSENSUS_HTTP}/eth/v1/node/syncing")
        if sync_data and "data" in sync_data:
            if sync_data["data"]["is_syncing"]:
                head_slot = sync_data["data"].get("head_slot")
                warn(f"Node is syncing (Head Slot: {head_slot})")
            else:
                ok("Node is fully synced and healthy.")
        else:
            ok("Node is healthy (HTTP 200).")
            
    elif code == 206:
        warn("Node is syncing (HTTP 206).")
    elif code == 503:
        error("Node is initializing / not ready (HTTP 503).")
    else:
        error(f"Unexpected beacon status: HTTP {code}")

# ======================================
# VALIDATOR STATUS & DUTIES
# ======================================

def check_validator():
    print(f"\n{BOLD}=== Checking Validator Duties ==={RESET}")

    if not VALIDATOR_INDEX:
        error("VALIDATOR_INDEX environment variable is not set.")
        return

    try:
        val_index_int = int(VALIDATOR_INDEX)
        val_index_str = str(val_index_int)
    except ValueError:
        error(f"VALIDATOR_INDEX '{VALIDATOR_INDEX}' is not a valid integer.")
        return

    # 1. Get Validator Status (Uses CONSENSUS_HTTP)
    # This works fine in your current setup
    v_url = f"{CONSENSUS_HTTP}/eth/v1/beacon/states/head/validators/{val_index_str}"
    v_data = http_get(v_url)

    if not v_data or "data" not in v_data:
        error(f"Could not find validator {val_index_str} in beacon state.")
        return

    status = v_data["data"]["status"]
    pubkey = v_data["data"]["validator"]["pubkey"]
    short_pk = f"{pubkey[:6]}...{pubkey[-4:]}"

    print(f"Validator: {short_pk} | Index: {val_index_str}")
    
    if "active" in status:
        ok(f"Status: {status}")
    elif "pending" in status:
        warn(f"Status: {status}")
    else:
        error(f"Status: {status}")

    # 2. Get Current Epoch
    head = http_get(f"{CONSENSUS_HTTP}/eth/v1/beacon/headers/head")
    if not head:
        error("Could not fetch chain head.")
        return
    
    current_slot = int(head["data"]["header"]["message"]["slot"])
    epoch = current_slot // 32
    
    # 3. Get Attestation Duties (FIXED)
    # Target: CONSENSUS_HTTP (Beacon Node), NOT Validator Client
    # Method: POST
    # Payload: Array of strings ["12345"]
    
    duties_url = f"{CONSENSUS_HTTP}/eth/v1/validator/duties/attester/{epoch}"
    payload = [val_index_str] 
    
    duties_data = http_post(duties_url, payload)

    if not duties_data or "data" not in duties_data:
        # If this returns empty, the node might not have calculated duties for this epoch yet
        warn(f"Could not fetch duties for epoch {epoch}. (Node might be busy or just switched epochs)")
        return

    # Find our specific duty in the response
    my_duty = next((d for d in duties_data["data"] if int(d["validator_index"]) == val_index_int), None)


    if my_duty:
        att_slot = int(my_duty["slot"])
        slots_away = att_slot - current_slot
        
        # CHANGED: Better labeling depending on if it is future or past
        if slots_away > 0:
            ok(f"Upcoming Duty: Slot {att_slot} (in {slots_away} slots)")
        elif slots_away == 0:
            warn(f"Attesting NOW: Slot {att_slot}")
        else:
            # It is in the past, so we just inform that the duty time has passed
            # We use OK color because passing a time isn't an error.
            ok(f"Past Duty: Slot {att_slot} ({abs(slots_away)} slots ago)")

    else:
        # This is rare for an active validator, but can happen if the node is confused
        warn(f"No attestation duties returned for epoch {epoch}.")

# ======================================
# MAIN
# ======================================

def main():
    print(f"{BOLD}======================================================")
    print(" HEALTH CHECK: Ethereum Validator Stack")
    print(f"======================================================{RESET}")

    check_geth_sync()
    check_consensus_sync()
    check_validator()

    print(f"\n{BOLD}======================================================{RESET}")

if __name__ == "__main__":
    main()