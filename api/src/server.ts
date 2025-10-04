import express, { Request, Response, NextFunction } from 'express';
import { createProxyMiddleware } from 'http-proxy-middleware';
import cors from 'cors';

const app = express();
const PORT = process.env.PORT || 8080;
const UPSTREAM_TILESERVER = process.env.UPSTREAM_TILESERVER || 'http://localhost:8081';

// Enable CORS for all routes
app.use(cors({
  origin: '*',
  methods: ['GET', 'HEAD', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Accept']
}));

// Health check endpoint
app.get('/healthz', (req: Request, res: Response) => {
  res.status(200).json({ status: 'ok', service: 'osm-tile-api' });
});

// Tile parameter validation middleware
const validateTileParams = (req: Request, res: Response, next: NextFunction) => {
  const { z, x, y } = req.params;
  
  const zNum = parseInt(z, 10);
  const xNum = parseInt(x, 10);
  const yNum = parseInt(y, 10);
  
  if (isNaN(zNum) || isNaN(xNum) || isNaN(yNum)) {
    return res.status(400).json({ error: 'Invalid tile coordinates' });
  }
  
  // Basic validation
  if (zNum < 0 || zNum > 22) {
    return res.status(400).json({ error: 'Zoom level must be between 0 and 22' });
  }
  
  const maxTile = Math.pow(2, zNum);
  if (xNum < 0 || xNum >= maxTile || yNum < 0 || yNum >= maxTile) {
    return res.status(400).json({ error: 'Tile coordinates out of range for zoom level' });
  }
  
  next();
};

// Vector tile endpoint - proxy to tileserver /data/v3/{z}/{x}/{y}.pbf
app.get('/tiles/:z/:x/:y.pbf', validateTileParams, createProxyMiddleware({
  target: UPSTREAM_TILESERVER,
  changeOrigin: true,
  pathRewrite: (path, req) => {
    const { z, x, y } = req.params;
    return `/data/v3/${z}/${x}/${y}.pbf`;
  },
  onProxyRes: (proxyRes, req, res) => {
    // Set caching headers
    proxyRes.headers['Cache-Control'] = 'public, max-age=86400'; // 24 hours
    proxyRes.headers['Access-Control-Allow-Origin'] = '*';
  },
  onError: (err, req, res) => {
    console.error('Proxy error:', err);
    res.status(502).json({ error: 'Bad Gateway', message: 'Failed to fetch tile from upstream server' });
  }
}));

// Raster tile endpoint - proxy to tileserver styles endpoint
// TileServer GL serves raster tiles at /styles/{style}/{z}/{x}/{y}.{format}
app.get('/tiles/:z/:x/:y.:format(png|jpg|jpeg)', validateTileParams, createProxyMiddleware({
  target: UPSTREAM_TILESERVER,
  changeOrigin: true,
  pathRewrite: (path, req) => {
    const { z, x, y, format } = req.params;
    // Use the basic style we defined
    return `/styles/basic/${z}/${x}/${y}.${format}`;
  },
  onProxyRes: (proxyRes, req, res) => {
    // Set caching headers
    proxyRes.headers['Cache-Control'] = 'public, max-age=86400'; // 24 hours
    proxyRes.headers['Access-Control-Allow-Origin'] = '*';
  },
  onError: (err, req, res) => {
    console.error('Proxy error:', err);
    res.status(502).json({ error: 'Bad Gateway', message: 'Failed to fetch tile from upstream server' });
  }
}));

// Root endpoint with API information
app.get('/', (req: Request, res: Response) => {
  res.json({
    service: 'OSM Tile API',
    version: '1.0.0',
    endpoints: {
      vector: '/tiles/{z}/{x}/{y}.pbf',
      raster_png: '/tiles/{z}/{x}/{y}.png',
      raster_jpg: '/tiles/{z}/{x}/{y}.jpg',
      health: '/healthz'
    },
    arcgis: {
      description: 'For ArcGIS Maps SDK WebTileLayer',
      urlTemplate: {
        vector: 'http://YOUR_HOST:' + PORT + '/tiles/{level}/{col}/{row}.pbf',
        raster: 'http://YOUR_HOST:' + PORT + '/tiles/{level}/{col}/{row}.png'
      },
      note: 'Replace YOUR_HOST with your server hostname or IP. Use {level}, {col}, {row} for ArcGIS, or {z}, {x}, {y} for standard XYZ.'
    }
  });
});

// 404 handler
app.use((req: Request, res: Response) => {
  res.status(404).json({ error: 'Not found', path: req.path });
});

// Error handler
app.use((err: Error, req: Request, res: Response, next: NextFunction) => {
  console.error('Server error:', err);
  res.status(500).json({ error: 'Internal server error' });
});

app.listen(PORT, () => {
  console.log(`OSM Tile API server listening on port ${PORT}`);
  console.log(`Proxying tiles from: ${UPSTREAM_TILESERVER}`);
  console.log(`Vector tiles: http://localhost:${PORT}/tiles/{z}/{x}/{y}.pbf`);
  console.log(`Raster tiles: http://localhost:${PORT}/tiles/{z}/{x}/{y}.png`);
});
