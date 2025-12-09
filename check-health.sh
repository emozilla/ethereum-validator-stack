#!/bin/bash

# Load .env file if exists
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

if [ -z "$VALIDATOR_INDEX" ]; then
    echo "ERROR: VALIDATOR_INDEX is not set in .env or environment"
    exit 1
fi

python3 fetch.py