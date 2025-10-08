# OpenStreetMap PostGIS TileServer

A complete, production-ready pipeline for generating and serving OpenStreetMap vector and raster tiles via PostGIS, OpenMapTiles, and TileServer GL. Includes a CORS-enabled API proxy for seamless integration with ArcGIS Maps SDK for JavaScript WebTileLayer.

## 🎯 Features

- **Import OSM Data**: Use imposm3 (default) or osm2pgsql to import PBF files into PostGIS
- **Generate MBTiles**: Create vector tiles from PostGIS using OpenMapTiles tools
- **Serve Tiles**: TileServer GL serves both vector (PBF) and raster (PNG/JPG) tiles
- **CORS-Enabled API**: Express-based proxy adds CORS headers for ArcGIS WebTileLayer compatibility
- **Docker-First**: Everything runs in containers - minimal local dependencies
- **Make-Based Workflow**: Simple commands to orchestrate the entire pipeline
- **Cross-Platform**: Works on Linux, macOS, and Windows (with WSL2/Docker Desktop)

## 📋 Prerequisites

- **Docker** (20.10+) and **Docker Compose** (v2.x+)
- At least **16GB RAM** and **50GB free disk space** for US data
- Downloaded PBF file from [Geofabrik](https://download.geofabrik.de/)

## 🚀 Quick Start

### 1. Download OSM Data

Download the PBF file for your region and place it in the `./data` directory:

```bash
# Create data directory
mkdir -p data

# Download US data (or your preferred region)
wget https://download.geofabrik.de/north-america/us-latest.osm.pbf -O data/us-latest.osm.pbf

# Or use the helper script
docker run --rm -v $(pwd)/data:/data alpine sh -c "apk add wget && wget https://download.geofabrik.de/north-america/us-latest.osm.pbf -O /data/us-latest.osm.pbf"
```

### 2. Run the Complete Pipeline

```bash
# Pull all required Docker images
docker compose pull

# Run everything: setup DB → import data → generate tiles → start servers
make all
```

This will:
1. Start PostgreSQL with PostGIS extension
2. Import OSM data using imposm3
3. Generate MBTiles file from PostGIS
4. Start TileServer GL and CORS-enabled API

### 3. Access Your Tiles

Once complete, you can access tiles at:

- **API (CORS-enabled for ArcGIS)**: http://localhost:8080/
  - Vector: `http://localhost:8080/tiles/{z}/{x}/{y}.pbf`
  - Raster PNG: `http://localhost:8080/tiles/{z}/{x}/{y}.png`
  - Raster JPG: `http://localhost:8080/tiles/{z}/{x}/{y}.jpg`

- **TileServer GL UI**: http://localhost:8081/

## 📚 Detailed Usage

### Available Make Targets

```bash
make help       # Display all available commands
make up         # Start PostgreSQL database only
make import     # Import OSM data (imposm3 or osm2pgsql based on .env)
make mbtiles    # Generate MBTiles from PostGIS
make serve      # Start TileServer GL and API
make all        # Run complete pipeline
make logs       # Tail logs from running services
make stop       # Stop all services
make clean      # Remove generated files (keep database)
make nuke       # Remove everything including database volumes
make indexes    # Create spatial indexes (mainly for osm2pgsql)
```

### Step-by-Step Workflow

```bash
# 1. Start PostgreSQL
make up

# 2. Import OSM data
make import

# 3. Generate MBTiles
make mbtiles

# 4. Start tile servers
make serve

# 5. View logs
make logs
```

## 🔧 Configuration

Edit `.env` to customize settings:

```bash
# Database Configuration
POSTGRES_DB=osm
POSTGRES_USER=osm
POSTGRES_PASSWORD=osm

# Importer Selection (imposm or osm2pgsql)
IMPORTER=imposm

# File Paths
PBF_PATH=/data/us-latest.osm.pbf
MBTILES_PATH=/data/us-latest.mbtiles

# Bounding Box (optional, for regional subsets)
# Example USA: -125,24,-66,50
BBOX=

# Ports
API_PORT=8080
TILESERVER_PORT=8081

# Tile Generation
MIN_ZOOM=0
MAX_ZOOM=14
```

### Switching Between Importers

**imposm3** (default, recommended):
- Faster import
- Better OpenMapTiles compatibility
- Optimized for tile generation

**osm2pgsql** (alternative):
```bash
# In .env file, set:
IMPORTER=osm2pgsql

# Then run:
make import
```

## 🗺️ ArcGIS Integration

### Using with ArcGIS Maps SDK for JavaScript

#### Vector Tiles (MapLibre GL JS style)

```javascript
// Use MapLibre GL JS or ESRI's vector tile layer
const map = new Map({
  basemap: {
    baseLayers: [
      new VectorTileLayer({
        url: "http://YOUR_HOST:8080/tiles/{z}/{x}/{y}.pbf"
      })
    ]
  }
});
```

#### Raster Tiles (WebTileLayer)

```javascript
import WebTileLayer from "@arcgis/core/layers/WebTileLayer";
import Map from "@arcgis/core/Map";
import MapView from "@arcgis/core/views/MapView";

// Create WebTileLayer with raster tiles
const osmLayer = new WebTileLayer({
  urlTemplate: "http://YOUR_HOST:8080/tiles/{level}/{col}/{row}.png",
  copyright: "© OpenStreetMap contributors"
});

// Create map with OSM basemap
const map = new Map({
  basemap: {
    baseLayers: [osmLayer]
  }
});

// Create view
const view = new MapView({
  container: "viewDiv",
  map: map,
  center: [-98.5795, 39.8283],
  zoom: 4
});
```

**Important**: Use `{level}`, `{col}`, `{row}` for ArcGIS WebTileLayer (not `{z}`, `{x}`, `{y}`).

### CORS Support

The API service automatically adds CORS headers:
```
Access-Control-Allow-Origin: *
Cache-Control: public, max-age=86400
```

No additional configuration needed for browser-based applications.

## 🏗️ Architecture

```
┌─────────────────┐
│   ArcGIS SDK    │
│   WebTileLayer  │
└────────┬────────┘
         │ HTTP
         ▼
┌─────────────────┐
│  API (Express)  │  ← CORS, caching, proxy
│   Port 8080     │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ TileServer GL   │  ← Serve PBF/PNG/JPG
│   Port 8081     │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   MBTiles File  │  ← us-latest.mbtiles
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ PostGIS + Data  │  ← Imported OSM data
└─────────────────┘
```

## 📂 Project Structure

```
.
├── .devcontainer/          # VS Code dev container config
│   └── devcontainer.json
├── api/                    # CORS-enabled Express API
│   ├── src/
│   │   └── server.ts
│   ├── Dockerfile
│   ├── package.json
│   └── tsconfig.json
├── data/                   # Data files (gitignored)
│   ├── us-latest.osm.pbf   # Place your PBF here
│   └── us-latest.mbtiles   # Generated tiles
├── openmaptiles/           # OpenMapTiles configuration
│   ├── mapping.yaml        # imposm3 mapping
│   └── openmaptiles.yaml   # Tileset definition
├── scripts/                # Shell scripts for pipeline
│   ├── import_imposm.sh
│   ├── import_osm2pgsql.sh
│   ├── generate_mbtiles.sh
│   └── download.sh
├── tileserver/             # TileServer GL config
│   ├── config.json
│   └── styles/
│       └── basic.json
├── docker-compose.yml      # Service definitions
├── Makefile               # Orchestration commands
├── .env                   # Configuration
└── README.md
```

## 🔍 Troubleshooting

### Import Fails

```bash
# Check if PBF file exists
ls -lh data/us-latest.osm.pbf

# Check PostgreSQL is running
docker compose ps postgis

# View import logs
docker compose logs imposm
```

### Tiles Not Generating

```bash
# Check if data was imported
docker compose exec postgis psql -U osm -d osm -c "\dt"

# Verify MBTiles file
ls -lh data/*.mbtiles
```

If you are using the default imposm3 import without a full OpenMapTiles schema, the `generate_mbtiles.sh` script now exports the
imposm tables with **GDAL/ogr2ogr** and builds a lightweight vector tile set with **tippecanoe**. Make sure the
`openmaptiles-tools` image (or your environment) includes these utilities. The fallback tileset bundles layers such as roads,
buildings, water, landuse, places, POIs, and administrative boundaries directly from the imposm output. The script will abort
with an error if no data can be exported instead of silently producing an empty placeholder MBTiles file.

### API Returns 502 Bad Gateway

```bash
# Ensure TileServer is running
docker compose ps tileserver

# Check TileServer logs
docker compose logs tileserver

# Verify MBTiles exists
ls -lh data/us-latest.mbtiles
```

### Out of Memory

If import fails with OOM:
1. Reduce the region size (use state/city extract instead of entire US)
2. Increase Docker memory limit (Docker Desktop: Settings → Resources)
3. Use BBOX parameter in `.env` to limit extent

### Performance Tips

1. **Use SSD storage** for data directory
2. **Allocate more RAM** to Docker (16GB+ recommended)
3. **Use smaller regions** for testing (e.g., single state)
4. **Adjust MAX_ZOOM** in `.env` (lower = faster generation)
5. **Use BBOX** to limit geographic extent

## 🌍 Regional Subsets

To process only a specific region (faster, less storage):

```bash
# In .env file:
BBOX=-125,24,-66,50  # Continental USA bounds

# Or download a smaller region:
wget https://download.geofabrik.de/north-america/us/california-latest.osm.pbf -O data/california.osm.pbf

# Update .env:
PBF_PATH=/data/california.osm.pbf
MBTILES_PATH=/data/california.mbtiles
```

## 🧪 Development

### Using VS Code Dev Container

1. Open project in VS Code
2. Click "Reopen in Container" when prompted
3. All dependencies are pre-installed
4. Ports are auto-forwarded

### Local API Development

```bash
cd api
pnpm install
pnpm run dev  # Start with hot reload
```

### Testing Tiles Locally

```bash
# Test vector tile
curl -I http://localhost:8080/tiles/0/0/0.pbf

# Test raster tile
curl -I http://localhost:8080/tiles/0/0/0.png

# View tile info
curl http://localhost:8081/data/v3.json
```

## 📊 Performance Benchmarks

Typical performance on a modern workstation (16GB RAM, SSD):

| Region          | PBF Size | Import Time | MBTiles Size | Generation Time |
|----------------|----------|-------------|--------------|-----------------|
| Rhode Island   | 12 MB    | 1-2 min     | ~100 MB      | 5-10 min        |
| California     | 450 MB   | 10-15 min   | ~2 GB        | 30-60 min       |
| USA            | 9 GB     | 60-90 min   | ~20 GB       | 4-8 hours       |
| Planet         | 66 GB    | 8-12 hours  | ~200 GB      | 24-48 hours     |

*Times vary based on hardware, zoom levels, and BBOX settings.*

## 📝 License

MIT License - see LICENSE file for details.

## 🙏 Credits

- [OpenStreetMap](https://www.openstreetmap.org/) - Map data
- [OpenMapTiles](https://openmaptiles.org/) - Tile schema and tools
- [imposm3](https://imposm.org/) - OSM importer
- [TileServer GL](https://github.com/maptiler/tileserver-gl) - Tile server
- [PostGIS](https://postgis.net/) - Spatial database

## 🔗 Useful Links

- [Geofabrik Downloads](https://download.geofabrik.de/) - OSM PBF files
- [OpenMapTiles Docs](https://openmaptiles.org/docs/)
- [ArcGIS Maps SDK](https://developers.arcgis.com/javascript/)
- [MapLibre GL JS](https://maplibre.org/) - Vector tile renderer

## 🤝 Contributing

Contributions welcome! Please open an issue or PR.

## 💡 Tips

- **Start small**: Test with a city or state before processing entire countries
- **Monitor resources**: Use `docker stats` to watch memory/CPU usage
- **Incremental updates**: imposm3 supports diff files for periodic updates
- **Production deployment**: Use nginx for SSL termination and caching
- **Scaling**: Consider PMTiles for serverless/CDN deployment