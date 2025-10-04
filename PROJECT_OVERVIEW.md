# Project Overview

## What is this?

A complete, production-ready OpenStreetMap tile server that:
- Imports OSM data into PostGIS
- Generates vector tiles (MBTiles format)
- Serves tiles via TileServer GL
- Provides CORS-enabled API for ArcGIS integration
- Runs entirely in Docker containers

## Key Features

### 🎯 Core Functionality
- ✅ Import OSM PBF files using imposm3 or osm2pgsql
- ✅ Generate OpenMapTiles-compatible vector tiles
- ✅ Serve vector tiles (PBF) and raster tiles (PNG/JPG)
- ✅ CORS-enabled API proxy for web applications
- ✅ ArcGIS Maps SDK WebTileLayer compatible

### 🐳 Docker-First Architecture
- ✅ PostgreSQL 16 with PostGIS 3.4
- ✅ imposm3 for fast OSM imports
- ✅ OpenMapTiles tools for tile generation
- ✅ TileServer GL for tile serving
- ✅ Node.js/Express API with TypeScript

### 🛠️ Developer Experience
- ✅ Make-based workflow (simple commands)
- ✅ VS Code dev container support
- ✅ Comprehensive documentation
- ✅ Example integrations (ArcGIS, MapLibre)
- ✅ Troubleshooting guide

## Project Structure

```
OpenStreetMap-PostGIS-TileServer/
├── .devcontainer/          # VS Code dev container
├── .github/                # CI/CD workflows
├── api/                    # CORS-enabled Express API
│   ├── src/
│   │   └── server.ts       # TypeScript API server
│   ├── Dockerfile
│   └── package.json
├── data/                   # Data files (gitignored)
│   ├── *.osm.pbf          # OSM data
│   └── *.mbtiles          # Generated tiles
├── examples/               # Integration examples
│   ├── arcgis-webtile-layer.html
│   ├── arcgis-vector-tiles.html
│   └── maplibre-gl.html
├── openmaptiles/           # Tile configuration
│   ├── mapping.yaml        # imposm3 mapping
│   └── openmaptiles.yaml   # Tileset definition
├── scripts/                # Shell scripts
│   ├── import_imposm.sh
│   ├── import_osm2pgsql.sh
│   ├── generate_mbtiles.sh
│   └── download.sh
├── tileserver/             # TileServer GL config
│   ├── config.json
│   └── styles/basic.json
├── docker-compose.yml      # Service definitions
├── Makefile               # Orchestration commands
├── .env                   # Configuration
└── README.md              # Main documentation
```

## Architecture

### Services

1. **PostGIS** (postgis/postgis:16-3.4)
   - PostgreSQL 16 with PostGIS 3.4 extension
   - Stores imported OSM data
   - Persists data in Docker volume

2. **imposm** (openmaptiles/import-osm:3.0.1)
   - Fast OSM data importer
   - Uses OpenMapTiles-compatible mapping
   - Run-once container (exits after import)

3. **openmaptiles-tools** (openmaptiles/openmaptiles-tools:7.4)
   - Generates vector tiles from PostGIS
   - Creates MBTiles file
   - Run-once container (exits after generation)

4. **TileServer GL** (maptiler/tileserver-gl:v4.6.5)
   - Serves vector and raster tiles
   - Renders PNG/JPG from vector tiles
   - Provides web UI for preview

5. **API** (Node 20 + TypeScript)
   - Express-based proxy
   - Adds CORS headers
   - Maps XYZ tile requests to TileServer
   - Validates tile parameters

### Data Flow

```
PBF File → PostgreSQL/PostGIS → MBTiles → TileServer GL → API → Client
    ↓           ↓                   ↓            ↓          ↓
  imposm    OSM tables         Vector tiles   Raster    CORS
                                              rendering headers
```

## Configuration Files

### Core Configuration
- **`.env`**: Environment variables (DB credentials, paths, ports)
- **`docker-compose.yml`**: Service definitions and networking
- **`Makefile`**: Workflow orchestration

### Import Configuration
- **`openmaptiles/mapping.yaml`**: imposm3 mapping rules
- **`openmaptiles/openmaptiles.yaml`**: Tileset metadata

### Server Configuration
- **`tileserver/config.json`**: TileServer GL settings
- **`tileserver/styles/basic.json`**: Default map style
- **`api/src/server.ts`**: API proxy logic

### Development Configuration
- **`.devcontainer/devcontainer.json`**: VS Code dev container
- **`.github/workflows/validate.yml`**: CI validation
- **`docker-compose.override.yml.example`**: Local overrides

## Workflows

### Initial Setup
```bash
make all
```
Runs: `up` → `import` → `mbtiles` → `serve`

### Individual Steps
```bash
make up        # Start PostgreSQL
make import    # Import OSM data
make mbtiles   # Generate tiles
make serve     # Start servers
```

### Maintenance
```bash
make logs      # View logs
make stop      # Stop services
make clean     # Remove generated files
make nuke      # Remove everything
```

## Key Technologies

### Data Processing
- **PostgreSQL 16**: Relational database
- **PostGIS 3.4**: Spatial extension
- **imposm3**: OSM importer (default)
- **osm2pgsql**: Alternative importer

### Tile Generation
- **OpenMapTiles**: Tile schema and tools
- **MBTiles**: Tile storage format (SQLite-based)
- **Tippecanoe**: Vector tile generator (alternative)

### Tile Serving
- **TileServer GL**: Tile server with rendering
- **Node.js 20**: JavaScript runtime
- **Express**: Web framework
- **TypeScript**: Type-safe JavaScript

### Frontend Integration
- **ArcGIS Maps SDK**: ESRI mapping library
- **MapLibre GL JS**: Open-source vector maps
- **Leaflet**: Lightweight mapping library

## Configuration Options

### Importer Selection
```bash
# .env
IMPORTER=imposm     # Fast, OpenMapTiles-native
IMPORTER=osm2pgsql  # Alternative, traditional
```

### Zoom Levels
```bash
# .env
MIN_ZOOM=0
MAX_ZOOM=14  # Lower = faster generation, less storage
```

### Geographic Extent
```bash
# .env
BBOX=-125,24,-66,50  # Continental USA
BBOX=-122.5,37.5,-121.5,38.5  # San Francisco Bay Area
```

### Ports
```bash
# .env
API_PORT=8080        # CORS-enabled API
TILESERVER_PORT=8081 # TileServer GL UI
```

## Performance Considerations

### Memory
- Minimum: 8GB RAM
- Recommended: 16GB+ RAM
- Large regions (USA): 32GB+ RAM

### Storage
- Rhode Island: ~500 MB
- California: ~5 GB
- USA: ~50 GB
- Planet: ~500 GB

### Processing Time
- Rhode Island: 5-15 minutes
- California: 30-90 minutes
- USA: 4-8 hours
- Planet: 24-48 hours

### Optimization Tips
1. Use SSD storage
2. Allocate more RAM to Docker
3. Use BBOX for regional subsets
4. Lower MAX_ZOOM for faster generation
5. Use imposm3 (faster than osm2pgsql)

## API Endpoints

### Tile Endpoints (API - Port 8080)
- Vector: `GET /tiles/{z}/{x}/{y}.pbf`
- Raster PNG: `GET /tiles/{z}/{x}/{y}.png`
- Raster JPG: `GET /tiles/{z}/{x}/{y}.jpg`
- Health: `GET /healthz`
- Info: `GET /`

### TileServer Endpoints (Port 8081)
- Web UI: `GET /`
- Vector tiles: `GET /data/v3/{z}/{x}/{y}.pbf`
- Style JSON: `GET /styles/basic/style.json`
- Raster: `GET /styles/basic/{z}/{x}/{y}.png`

## Security Considerations

### Current Setup (Development)
- ⚠️ Open CORS (`*`)
- ⚠️ Default credentials
- ⚠️ No SSL/TLS
- ⚠️ No rate limiting
- ⚠️ No authentication

### Production Recommendations
1. **Use SSL/TLS**: nginx + Let's Encrypt
2. **Restrict CORS**: Specific origins only
3. **Change credentials**: Strong passwords
4. **Add rate limiting**: nginx or API middleware
5. **Enable authentication**: API keys or OAuth
6. **Use firewall**: Restrict direct access to PostGIS

## Extensibility

### Adding Custom Layers
Edit `openmaptiles/mapping.yaml` to add custom imposm3 tables.

### Custom Styles
Add JSON files to `tileserver/styles/` and reference in `config.json`.

### Custom Endpoints
Modify `api/src/server.ts` to add new routes or logic.

### Additional Services
Add to `docker-compose.yml` for monitoring, caching, etc.

## Future Enhancements

### Planned Features
- [ ] PMTiles export for serverless hosting
- [ ] Automated diff updates (incremental)
- [ ] Raster tile pre-seeding
- [ ] Monitoring dashboard (Grafana)
- [ ] Multiple style support
- [ ] Tile cache warming
- [ ] API rate limiting
- [ ] Authentication/authorization

### Community Contributions
- Custom mappings for specialized use cases
- Additional example integrations
- Performance optimizations
- Cloud deployment guides (AWS, GCP, Azure)
- Kubernetes manifests

## Resources

### Documentation
- [README.md](README.md): Full documentation
- [QUICKSTART.md](QUICKSTART.md): 5-minute setup guide
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md): Common issues
- [CONTRIBUTING.md](CONTRIBUTING.md): Contribution guide
- [examples/README.md](examples/README.md): Integration examples

### External Resources
- [OpenStreetMap](https://www.openstreetmap.org/)
- [Geofabrik Downloads](https://download.geofabrik.de/)
- [OpenMapTiles](https://openmaptiles.org/)
- [TileServer GL](https://tileserver.readthedocs.io/)
- [ArcGIS Maps SDK](https://developers.arcgis.com/javascript/)

## License

MIT License - see [LICENSE](LICENSE) for details.

## Credits

Built on top of:
- OpenStreetMap data (ODbL license)
- OpenMapTiles schema (BSD license)
- imposm3 (Apache 2.0 license)
- PostGIS (GPL license)
- TileServer GL (BSD license)
