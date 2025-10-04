#!/bin/bash
set -euo pipefail

echo "=== Starting imposm3 import ==="

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL to be ready..."
until pg_isready -h "${POSTGRES_HOST}" -p "${POSTGRES_PORT}" -U "${POSTGRES_USER}"; do
  echo "PostgreSQL is unavailable - sleeping"
  sleep 2
done
echo "PostgreSQL is ready!"

# Check if PBF file exists
if [ ! -f "${PBF_PATH}" ]; then
  echo "ERROR: PBF file not found at ${PBF_PATH}"
  exit 1
fi

echo "PBF file found: ${PBF_PATH}"
echo "Database: ${POSTGRES_DB}@${POSTGRES_HOST}:${POSTGRES_PORT}"

# Set up imposm3 connection string
export IMPOSM_CONNECTION="postgis://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${POSTGRES_HOST}:${POSTGRES_PORT}/${POSTGRES_DB}"

# Use OpenMapTiles mapping if available, otherwise use a basic mapping
MAPPING_FILE="/mapping/mapping.yaml"
if [ ! -f "${MAPPING_FILE}" ]; then
  echo "WARNING: Mapping file not found at ${MAPPING_FILE}, using default imposm3 mapping"
  MAPPING_FILE=""
fi

# Create cache directory
CACHE_DIR="/data/imposm3cache"
mkdir -p "${CACHE_DIR}"

# Run imposm3 import
echo "Running imposm3 read..."
if [ -n "${MAPPING_FILE}" ]; then
  imposm import \
    -mapping "${MAPPING_FILE}" \
    -read "${PBF_PATH}" \
    -cachedir "${CACHE_DIR}" \
    -overwritecache
else
  imposm import \
    -read "${PBF_PATH}" \
    -cachedir "${CACHE_DIR}" \
    -overwritecache
fi

echo "Running imposm3 write..."
if [ -n "${MAPPING_FILE}" ]; then
  imposm import \
    -mapping "${MAPPING_FILE}" \
    -write \
    -cachedir "${CACHE_DIR}" \
    -connection "${IMPOSM_CONNECTION}"
else
  imposm import \
    -write \
    -cachedir "${CACHE_DIR}" \
    -connection "${IMPOSM_CONNECTION}"
fi

echo "Running imposm3 deploy..."
if [ -n "${MAPPING_FILE}" ]; then
  imposm import \
    -mapping "${MAPPING_FILE}" \
    -deployproduction \
    -connection "${IMPOSM_CONNECTION}"
else
  imposm import \
    -deployproduction \
    -connection "${IMPOSM_CONNECTION}"
fi

echo "=== imposm3 import completed successfully! ==="
