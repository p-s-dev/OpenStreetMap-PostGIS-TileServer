# Quick Start Guide

Get your OpenStreetMap tile server running in 5 minutes!

## Prerequisites

- Docker & Docker Compose installed
- 16GB+ RAM
- 50GB+ free disk space

## Step 1: Clone & Setup

```bash
git clone https://github.com/p-s-dev/OpenStreetMap-PostGIS-TileServer.git
cd OpenStreetMap-PostGIS-TileServer
```

## Step 2: Download OSM Data

Choose your region from [Geofabrik](https://download.geofabrik.de/):

```bash
# Example: California
wget https://download.geofabrik.de/north-america/us/california-latest.osm.pbf \
  -O data/us-latest.osm.pbf

# Or full USA (large!)
wget https://download.geofabrik.de/north-america/us-latest.osm.pbf \
  -O data/us-latest.osm.pbf
```

## Step 3: Pull Docker Images

```bash
docker compose pull
docker compose --profile import pull
docker compose --profile mbtiles pull
docker compose --profile serve pull
```

## Step 4: Run Everything

```bash
make all
```

This will:
1. ✓ Start PostgreSQL with PostGIS
2. ✓ Import OSM data using imposm3
3. ✓ Generate vector tiles (MBTiles)
4. ✓ Start TileServer GL
5. ✓ Start CORS-enabled API

**Time estimate**: 15-60 minutes depending on region size.

## Step 5: Access Tiles

Open your browser:

- **TileServer UI**: http://localhost:8081/
- **API Info**: http://localhost:8080/

Test a tile:
```bash
curl -I http://localhost:8080/tiles/0/0/0.pbf
```

## Step 6: Use in ArcGIS

### WebTileLayer (Raster)

```javascript
import WebTileLayer from "@arcgis/core/layers/WebTileLayer";

const osmLayer = new WebTileLayer({
  urlTemplate: "http://localhost:8080/tiles/{level}/{col}/{row}.png"
});
```

### VectorTileLayer (Vector)

```javascript
import VectorTileLayer from "@arcgis/core/layers/VectorTileLayer";

const vectorLayer = new VectorTileLayer({
  url: "http://localhost:8080/tiles/{z}/{x}/{y}.pbf"
});
```

## Common Commands

```bash
make help       # Show all commands
make logs       # View logs
make stop       # Stop services
make clean      # Remove generated tiles
make nuke       # Remove everything (including DB)
```

## Troubleshooting

### Import fails?
```bash
# Check logs
docker compose logs imposm

# Verify PBF exists
ls -lh data/*.osm.pbf
```

### Out of memory?
- Use a smaller region (state instead of country)
- Increase Docker memory limit
- Lower MAX_ZOOM in .env

### Tiles not loading?
```bash
# Check services are running
docker compose ps

# Verify MBTiles exists
ls -lh data/*.mbtiles
```

## Next Steps

1. **Production**: Add nginx with SSL
2. **Performance**: Tune PostgreSQL settings
3. **Updates**: Set up imposm3 diff updates
4. **CDN**: Export to PMTiles for serverless hosting

See [README.md](README.md) for full documentation.
