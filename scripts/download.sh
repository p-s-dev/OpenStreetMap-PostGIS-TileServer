#!/bin/bash
set -euo pipefail

echo "=== OpenStreetMap PBF Download Helper ==="

# Default to US extract
REGION="${1:-north-america/us-latest}"
OUTPUT_DIR="/data"
GEOFABRIK_URL="https://download.geofabrik.de"

# Parse region to filename
FILENAME=$(basename "${REGION}").osm.pbf
OUTPUT_PATH="${OUTPUT_DIR}/${FILENAME}"

echo "Region: ${REGION}"
echo "Output: ${OUTPUT_PATH}"

# Check if file already exists
if [ -f "${OUTPUT_PATH}" ]; then
  echo "File already exists: ${OUTPUT_PATH}"
  read -p "Overwrite? [y/N] " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Download cancelled."
    exit 0
  fi
fi

# Download with wget or curl
DOWNLOAD_URL="${GEOFABRIK_URL}/${REGION}.osm.pbf"
echo "Downloading from: ${DOWNLOAD_URL}"

if command -v wget &> /dev/null; then
  wget -O "${OUTPUT_PATH}" "${DOWNLOAD_URL}"
elif command -v curl &> /dev/null; then
  curl -L -o "${OUTPUT_PATH}" "${DOWNLOAD_URL}"
else
  echo "ERROR: Neither wget nor curl found. Please install one of them."
  exit 1
fi

echo "Download complete!"
ls -lh "${OUTPUT_PATH}"

echo ""
echo "You can now run: make import"
