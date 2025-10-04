# Examples

This directory contains example HTML files demonstrating how to use the tile server with various mapping libraries.

## Files

### 1. arcgis-webtile-layer.html
**Recommended for ArcGIS Maps SDK**

Uses `WebTileLayer` to display raster (PNG) tiles. This is the most compatible approach for ArcGIS Maps SDK for JavaScript.

**Usage:**
```bash
# Start your tile server
make serve

# Open the file in a browser
open arcgis-webtile-layer.html
```

Key features:
- Uses raster tiles (PNG format)
- Full CORS support
- Works with standard ArcGIS WebTileLayer
- URL template: `http://localhost:8080/tiles/{level}/{col}/{row}.png`

### 2. arcgis-vector-tiles.html
**Experimental - Vector tile approach**

Attempts to use `VectorTileLayer` with vector tiles. Note that this may have compatibility issues since OpenMapTiles format differs from ESRI vector tile format.

**Better alternative:** Use MapLibre GL JS for vector tiles (see below).

### 3. maplibre-gl.html
**Best for Vector Tiles**

Uses MapLibre GL JS to render vector tiles. This library has native support for OpenMapTiles format and provides smooth, client-side rendering.

**Usage:**
```bash
# Start your tile server
make serve

# Open the file in a browser
open maplibre-gl.html
```

Key features:
- Vector tile rendering
- Smooth zooming and rotation
- Client-side styling
- Better performance for interactive maps
- URL template: `http://localhost:8080/tiles/{z}/{x}/{y}.pbf`

## Testing

### Local Testing

1. **Start the tile server:**
   ```bash
   make serve
   ```

2. **Serve the examples with a local web server:**
   ```bash
   # Using Python
   python3 -m http.server 8000
   
   # Or using Node.js
   npx http-server -p 8000
   ```

3. **Open in browser:**
   ```
   http://localhost:8000/examples/arcgis-webtile-layer.html
   http://localhost:8000/examples/maplibre-gl.html
   ```

### Production Deployment

For production use, replace `localhost` with your server's hostname or IP:

```javascript
// Development
urlTemplate: "http://localhost:8080/tiles/{level}/{col}/{row}.png"

// Production
urlTemplate: "https://your-domain.com/tiles/{level}/{col}/{row}.png"
```

## Recommendations

| Use Case | Recommended Example | Library | Format |
|----------|-------------------|---------|---------|
| ArcGIS SDK Integration | arcgis-webtile-layer.html | ArcGIS Maps SDK | Raster (PNG) |
| Interactive Vector Maps | maplibre-gl.html | MapLibre GL JS | Vector (PBF) |
| Lightweight Basemap | arcgis-webtile-layer.html | ArcGIS Maps SDK | Raster (PNG) |
| Custom Styling | maplibre-gl.html | MapLibre GL JS | Vector (PBF) |

## CORS Notes

All examples work with the CORS-enabled API (port 8080) which automatically adds:
- `Access-Control-Allow-Origin: *`
- `Cache-Control: public, max-age=86400`

If you need to restrict CORS origins, modify `api/src/server.ts`:

```typescript
app.use(cors({
  origin: ['https://your-domain.com', 'https://app.your-domain.com'],
  methods: ['GET', 'HEAD', 'OPTIONS']
}));
```

## Troubleshooting

### Tiles not loading?
1. Verify tile server is running: `docker compose ps`
2. Check API is accessible: `curl http://localhost:8080/healthz`
3. Test a tile endpoint: `curl -I http://localhost:8080/tiles/0/0/0.pbf`

### CORS errors?
- Ensure you're accessing via the API (port 8080), not TileServer directly (port 8081)
- Check browser console for specific CORS errors
- Verify API CORS settings in `api/src/server.ts`

### Blank map?
1. Verify MBTiles file exists: `ls -lh data/*.mbtiles`
2. Check TileServer logs: `docker compose logs tileserver`
3. Ensure data was imported: `make import`
4. Try regenerating tiles: `make mbtiles`

## Further Reading

- [ArcGIS Maps SDK for JavaScript](https://developers.arcgis.com/javascript/)
- [MapLibre GL JS Documentation](https://maplibre.org/maplibre-gl-js-docs/)
- [OpenMapTiles Schema](https://openmaptiles.org/schema/)
- [TileServer GL Documentation](https://tileserver.readthedocs.io/)
