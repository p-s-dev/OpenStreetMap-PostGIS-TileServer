#!/bin/bash
set -euo pipefail

echo "=== Starting MBTiles generation ==="

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL to be ready..."
until pg_isready -h "${POSTGRES_HOST}" -p "${POSTGRES_PORT}" -U "${POSTGRES_USER}"; do
  echo "PostgreSQL is unavailable - sleeping"
  sleep 2
done
echo "PostgreSQL is ready!"

# Set up database connection
export DATABASE_URL="postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${POSTGRES_HOST}:${POSTGRES_PORT}/${POSTGRES_DB}"

# Check if tileset configuration exists
TILESET_FILE="/tileset/openmaptiles.yaml"
if [ ! -f "${TILESET_FILE}" ]; then
  echo "WARNING: Tileset configuration not found at ${TILESET_FILE}"
  echo "Creating a minimal tileset configuration..."
  
  mkdir -p /tileset
  cat > "${TILESET_FILE}" << 'EOF'
tileset:
  name: OpenStreetMap
  version: 1.0.0
  id: osm
  description: OpenStreetMap tiles
  attribution: © OpenStreetMap contributors
  center: [-98.5795, 39.8283, 4]
  bounds: [-180, -85.0511, 180, 85.0511]
  minzoom: 0
  maxzoom: 14
  pixel_scale: 256
  layers: []
EOF
fi

echo "Tileset configuration: ${TILESET_FILE}"
echo "Output MBTiles: ${MBTILES_PATH}"
echo "Zoom range: ${MIN_ZOOM:-0} to ${MAX_ZOOM:-14}"

# Build bbox parameter if set
BBOX_PARAM=""
if [ -n "${BBOX}" ]; then
  echo "Using bounding box: ${BBOX}"
  BBOX_PARAM="--bbox=${BBOX}"
fi

# Create output directory if it doesn't exist
mkdir -p "$(dirname ${MBTILES_PATH})"

# Generate tiles using openmaptiles-tools
cd /tileset

# If we have a proper OpenMapTiles setup, use generate-tiles
if [ -f "/tileset/openmaptiles.yaml" ] && [ -d "/tileset/layers" ]; then
  echo "Using OpenMapTiles generate-tiles..."
  generate-tiles \
    --minzoom="${MIN_ZOOM:-0}" \
    --maxzoom="${MAX_ZOOM:-14}" \
    ${BBOX_PARAM} \
    "${TILESET_FILE}" \
    "${MBTILES_PATH}"
else
  # Fallback: Use tilelive-copy or tilemaker approach
  echo "Using simple tile generation approach..."
  
  # Use tippecanoe if available to generate from PostGIS
  if command -v tippecanoe &> /dev/null; then
    echo "Using tippecanoe for tile generation..."
    
    # Export data from PostGIS to GeoJSON and pipe to tippecanoe
    psql "${DATABASE_URL}" -t -c "SELECT json_build_object(
      'type', 'FeatureCollection',
      'features', json_agg(ST_AsGeoJSON(t.*)::json)
    ) FROM (SELECT * FROM public.osm_roads LIMIT 10000) AS t;" | \
    tippecanoe \
      -o "${MBTILES_PATH}" \
      -z "${MAX_ZOOM:-14}" \
      -Z "${MIN_ZOOM:-0}" \
      -f \
      -l osm
  else
    # Ultimate fallback: create empty MBTiles
    echo "Creating placeholder MBTiles..."
    echo "Note: For production use, please use OpenMapTiles with proper configuration"
    
    sqlite3 "${MBTILES_PATH}" <<SQL
CREATE TABLE metadata (name text, value text);
INSERT INTO metadata VALUES('name', 'OpenStreetMap');
INSERT INTO metadata VALUES('type', 'baselayer');
INSERT INTO metadata VALUES('version', '1.0.0');
INSERT INTO metadata VALUES('description', 'OpenStreetMap tiles');
INSERT INTO metadata VALUES('format', 'pbf');
INSERT INTO metadata VALUES('minzoom', '${MIN_ZOOM:-0}');
INSERT INTO metadata VALUES('maxzoom', '${MAX_ZOOM:-14}');
INSERT INTO metadata VALUES('bounds', '-180,-85.0511,180,85.0511');
INSERT INTO metadata VALUES('center', '-98.5795,39.8283,4');

CREATE TABLE tiles (zoom_level integer, tile_column integer, tile_row integer, tile_data blob);
CREATE UNIQUE INDEX tile_index on tiles (zoom_level, tile_column, tile_row);
SQL
    echo "Placeholder MBTiles created. Import data first for actual tiles."
  fi
fi

echo "=== MBTiles generation completed! ==="
ls -lh "${MBTILES_PATH}"
