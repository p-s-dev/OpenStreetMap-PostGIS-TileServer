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
mkdir -p "$(dirname "${MBTILES_PATH}")"

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
  # Fallback: Use tippecanoe to build a lightweight tileset from imposm output
  echo "Using imposm tables with tippecanoe..."

  if ! command -v tippecanoe &> /dev/null; then
    echo "ERROR: tippecanoe is not available in this environment." >&2
    echo "Install tippecanoe or provide an OpenMapTiles configuration." >&2
    exit 1
  fi

  if ! command -v ogr2ogr &> /dev/null; then
    echo "ERROR: ogr2ogr (GDAL) is required to export data from PostGIS." >&2
    exit 1
  fi

  OGR_CONN="PG:host=${POSTGRES_HOST} port=${POSTGRES_PORT} dbname=${POSTGRES_DB} user=${POSTGRES_USER} password=${POSTGRES_PASSWORD}"

  SPAT_ARGS=()
  if [ -n "${BBOX}" ]; then
    IFS=',' read -r BBOX_MIN_LON BBOX_MIN_LAT BBOX_MAX_LON BBOX_MAX_LAT <<< "${BBOX}"
    echo "Applying spatial filter: ${BBOX_MIN_LON},${BBOX_MIN_LAT},${BBOX_MAX_LON},${BBOX_MAX_LAT}"
    SPAT_ARGS=(-spat "${BBOX_MIN_LON}" "${BBOX_MIN_LAT}" "${BBOX_MAX_LON}" "${BBOX_MAX_LAT}")
  fi

  TMP_EXPORT_DIR="$(mktemp -d)"
  trap 'rm -rf "${TMP_EXPORT_DIR}"' EXIT

  declare -A LAYER_TABLES=(
    [water]="osm_osm_water"
    [waterways]="osm_osm_waterways"
    [landuse]="osm_osm_landuse"
    [roads]="osm_osm_roads"
    [buildings]="osm_osm_buildings"
    [places]="osm_osm_places"
    [pois]="osm_osm_pois"
    [admin]="osm_osm_admin"
  )

  TIPPECANOE_LAYERS=()
  DATA_FOUND=0

  for LAYER in "${!LAYER_TABLES[@]}"; do
    TABLE_NAME="${LAYER_TABLES[${LAYER}]}"

    TABLE_EXISTS=$(psql "${DATABASE_URL}" -Atc "SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = '${TABLE_NAME}');")
    if [ "${TABLE_EXISTS}" != "t" ]; then
      echo "Skipping layer '${LAYER}' (missing table public.${TABLE_NAME})."
      continue
    fi

    echo "Exporting layer '${LAYER}' from table public.${TABLE_NAME}..."

    OUTPUT_PATH="${TMP_EXPORT_DIR}/${LAYER}.geojsonseq"
    if ogr2ogr -f GeoJSONSeq "${OUTPUT_PATH}" "${OGR_CONN}" "public.${TABLE_NAME}" "${SPAT_ARGS[@]}" -nln "${LAYER}" -t_srs EPSG:4326 -lco RFC7946=YES >"${TMP_EXPORT_DIR}/${LAYER}_ogr2ogr.log" 2>&1; then
      if [ -s "${OUTPUT_PATH}" ]; then
        TIPPECANOE_LAYERS+=(-L "${LAYER}:${OUTPUT_PATH}")
        DATA_FOUND=1
      else
        echo "Layer '${LAYER}' did not produce any features."
      fi
    else
      echo "WARNING: Failed to export layer '${LAYER}'. ogr2ogr output:" >&2
      cat "${TMP_EXPORT_DIR}/${LAYER}_ogr2ogr.log" >&2 || true
    fi
  done

  if [ "${DATA_FOUND}" -eq 0 ]; then
    echo "ERROR: No data exported from imposm tables. Cannot build MBTiles." >&2
    exit 1
  fi

  echo "Generating MBTiles with tippecanoe..."
  tippecanoe \
    -o "${MBTILES_PATH}" \
    -Z "${MIN_ZOOM:-0}" \
    -z "${MAX_ZOOM:-14}" \
    --force \
    --drop-densest-as-needed \
    --extend-zooms-if-still-dropping \
    "${TIPPECANOE_LAYERS[@]}"
fi

echo "=== MBTiles generation completed! ==="
ls -lh "${MBTILES_PATH}"
