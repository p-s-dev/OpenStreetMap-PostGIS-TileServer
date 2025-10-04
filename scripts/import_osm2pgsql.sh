#!/bin/bash
set -euo pipefail

echo "=== Starting osm2pgsql import ==="

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

# Set up database connection
export PGHOST="${POSTGRES_HOST}"
export PGPORT="${POSTGRES_PORT}"
export PGUSER="${POSTGRES_USER}"
export PGPASSWORD="${POSTGRES_PASSWORD}"
export PGDATABASE="${POSTGRES_DB}"

# Calculate number of processes
NPROC=$(nproc)
echo "Using ${NPROC} processes"

# Create cache directory
CACHE_DIR="/data/cache"
mkdir -p "${CACHE_DIR}"

# Check if flex style exists
STYLE_FILE="/mapping/openstreetmap-carto.lua"
if [ -f "${STYLE_FILE}" ]; then
  echo "Using flex style: ${STYLE_FILE}"
  STYLE_OPTS="--style ${STYLE_FILE}"
else
  echo "Using default osm2pgsql style"
  STYLE_OPTS=""
fi

# Run osm2pgsql
echo "Running osm2pgsql..."
osm2pgsql \
  --create \
  --slim \
  --drop \
  --hstore \
  --multi-geometry \
  --number-processes "${NPROC}" \
  --tag-transform-script /usr/share/osm2pgsql/style.lua \
  --cache 2048 \
  --flat-nodes "${CACHE_DIR}/nodes.bin" \
  --database "${POSTGRES_DB}" \
  --host "${POSTGRES_HOST}" \
  --port "${POSTGRES_PORT}" \
  --username "${POSTGRES_USER}" \
  ${STYLE_OPTS} \
  "${PBF_PATH}"

echo "Creating spatial indexes..."
psql -c "CREATE INDEX IF NOT EXISTS idx_planet_osm_point_way ON planet_osm_point USING GIST (way);"
psql -c "CREATE INDEX IF NOT EXISTS idx_planet_osm_line_way ON planet_osm_line USING GIST (way);"
psql -c "CREATE INDEX IF NOT EXISTS idx_planet_osm_polygon_way ON planet_osm_polygon USING GIST (way);"
psql -c "CREATE INDEX IF NOT EXISTS idx_planet_osm_roads_way ON planet_osm_roads USING GIST (way);"

echo "=== osm2pgsql import completed successfully! ==="
