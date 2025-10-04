# Troubleshooting Guide

Common issues and their solutions.

## Table of Contents

- [Installation Issues](#installation-issues)
- [Import Issues](#import-issues)
- [Tile Generation Issues](#tile-generation-issues)
- [Server Issues](#server-issues)
- [Performance Issues](#performance-issues)
- [Network Issues](#network-issues)

## Installation Issues

### Docker Compose not found

**Error:**
```
docker: 'compose' is not a docker command
```

**Solution:**
- Install Docker Compose v2: https://docs.docker.com/compose/install/
- Or use `docker-compose` (v1) instead of `docker compose`

### Permission denied errors

**Error:**
```
permission denied while trying to connect to the Docker daemon socket
```

**Solution:**
```bash
# Add your user to docker group
sudo usermod -aG docker $USER

# Log out and back in, or run:
newgrp docker
```

## Import Issues

### PBF file not found

**Error:**
```
ERROR: PBF file not found at ./data/us-latest.osm.pbf
```

**Solution:**
```bash
# Download the file
wget https://download.geofabrik.de/north-america/us-latest.osm.pbf -O data/us-latest.osm.pbf

# Or use a smaller region for testing
wget https://download.geofabrik.de/north-america/us/rhode-island-latest.osm.pbf -O data/us-latest.osm.pbf
```

### PostgreSQL connection refused

**Error:**
```
could not connect to server: Connection refused
```

**Solution:**
```bash
# Ensure PostgreSQL is running
docker compose ps postgis

# Start PostgreSQL
make up

# Wait for it to be ready
docker compose exec postgis pg_isready -U osm -d osm
```

### Import runs out of memory

**Error:**
```
Killed
```
or
```
Cannot allocate memory
```

**Solution:**

1. **Increase Docker memory limit:**
   - Docker Desktop: Settings → Resources → Memory → 16GB+

2. **Use a smaller region:**
   ```bash
   # State instead of country
   wget https://download.geofabrik.de/north-america/us/california-latest.osm.pbf -O data/us-latest.osm.pbf
   ```

3. **Use BBOX to limit extent:**
   ```bash
   # In .env
   BBOX=-122.5,37.5,-121.5,38.5  # San Francisco Bay Area
   ```

4. **Lower zoom levels:**
   ```bash
   # In .env
   MAX_ZOOM=12  # Instead of 14
   ```

### Import is very slow

**Symptoms:**
- Import takes hours for small regions
- CPU usage is low

**Solutions:**

1. **Use SSD storage:**
   - Move data directory to SSD
   - Set Docker to use SSD for volumes

2. **Increase PostgreSQL performance:**
   ```yaml
   # In docker-compose.override.yml
   services:
     postgis:
       command:
         - postgres
         - -c
         - shared_buffers=2GB
         - -c
         - work_mem=256MB
         - -c
         - maintenance_work_mem=1GB
         - -c
         - checkpoint_completion_target=0.9
   ```

3. **Use imposm instead of osm2pgsql:**
   ```bash
   # In .env
   IMPORTER=imposm
   ```

## Tile Generation Issues

### MBTiles file is empty or very small

**Check:**
```bash
ls -lh data/*.mbtiles
sqlite3 data/us-latest.mbtiles "SELECT COUNT(*) FROM tiles;"
```

**Solutions:**

1. **Verify data was imported:**
   ```bash
   docker compose exec postgis psql -U osm -d osm -c "\dt"
   ```

2. **Check for errors in generation:**
   ```bash
   docker compose logs openmaptiles-tools
   ```

3. **Verify BBOX is correct:**
   ```bash
   # In .env, ensure BBOX covers your region
   BBOX=-125,24,-66,50  # Continental USA
   ```

### Tile generation fails

**Error:**
```
Error generating tiles
```

**Solutions:**

1. **Check disk space:**
   ```bash
   df -h
   ```

2. **Verify database connection:**
   ```bash
   docker compose exec postgis psql -U osm -d osm -c "SELECT 1;"
   ```

3. **Review logs:**
   ```bash
   docker compose logs openmaptiles-tools
   ```

## Server Issues

### TileServer won't start

**Error:**
```
Error: Cannot find module 'mbtiles'
```

**Solution:**
```bash
# Verify MBTiles file exists
ls -lh data/us-latest.mbtiles

# Check TileServer logs
docker compose logs tileserver

# Restart TileServer
docker compose restart tileserver
```

### API returns 502 Bad Gateway

**Error:**
```
{"error":"Bad Gateway","message":"Failed to fetch tile from upstream server"}
```

**Solutions:**

1. **Check TileServer is running:**
   ```bash
   docker compose ps tileserver
   ```

2. **Verify TileServer is accessible:**
   ```bash
   curl http://localhost:8081/
   ```

3. **Check network connectivity:**
   ```bash
   docker compose exec api curl http://tileserver:8080/
   ```

4. **Review API logs:**
   ```bash
   docker compose logs api
   ```

### Tiles return 404

**Error:**
```
404 Not Found
```

**Solutions:**

1. **Verify tile exists:**
   ```bash
   # Check a known tile (0/0/0)
   curl -I http://localhost:8080/tiles/0/0/0.pbf
   ```

2. **Check MBTiles content:**
   ```bash
   sqlite3 data/us-latest.mbtiles "SELECT zoom_level, COUNT(*) FROM tiles GROUP BY zoom_level;"
   ```

3. **Verify zoom range:**
   ```bash
   # Ensure you're requesting tiles within MIN_ZOOM and MAX_ZOOM
   # Check .env settings
   ```

## Performance Issues

### Tiles load slowly

**Solutions:**

1. **Enable caching:**
   - API already sets `Cache-Control: max-age=86400`
   - Add nginx reverse proxy with additional caching

2. **Pre-generate tiles:**
   ```bash
   # Seed commonly used zoom levels
   # (Future feature - not yet implemented)
   ```

3. **Use CDN:**
   - Deploy MBTiles to CDN
   - Use PMTiles for direct CDN hosting

### High memory usage

**Solutions:**

1. **Limit zoom levels:**
   ```bash
   # In .env
   MAX_ZOOM=12  # Lower max zoom
   ```

2. **Reduce tile resolution:**
   - Use 256x256 tiles (default)
   - Don't use @2x retina tiles

3. **Limit concurrent requests:**
   ```yaml
   # In docker-compose.yml, add to tileserver:
   deploy:
     resources:
       limits:
         memory: 4G
   ```

### Database is slow

**Solutions:**

1. **Create indexes:**
   ```bash
   make indexes
   ```

2. **Analyze tables:**
   ```bash
   docker compose exec postgis psql -U osm -d osm -c "ANALYZE;"
   ```

3. **Tune PostgreSQL:**
   ```bash
   # Use docker-compose.override.yml
   cp docker-compose.override.yml.example docker-compose.override.yml
   # Edit and restart
   ```

## Network Issues

### CORS errors in browser

**Error:**
```
Access to XMLHttpRequest has been blocked by CORS policy
```

**Solutions:**

1. **Use API endpoint (port 8080), not TileServer (8081):**
   ```javascript
   // Wrong
   url: "http://localhost:8081/data/v3/{z}/{x}/{y}.pbf"
   
   // Correct
   url: "http://localhost:8080/tiles/{z}/{x}/{y}.pbf"
   ```

2. **Check API CORS settings:**
   ```bash
   # Verify CORS headers
   curl -I -H "Origin: http://example.com" http://localhost:8080/tiles/0/0/0.pbf
   ```

3. **Custom CORS origins:**
   ```typescript
   // In api/src/server.ts
   app.use(cors({
     origin: ['http://localhost:3000', 'https://your-app.com']
   }));
   ```

### Cannot connect to localhost

**Error when using in production:**
```
Failed to fetch
```

**Solution:**
```javascript
// Replace localhost with your server's hostname
// Development
urlTemplate: "http://localhost:8080/tiles/{level}/{col}/{row}.png"

// Production
urlTemplate: "https://tiles.your-domain.com/tiles/{level}/{col}/{row}.png"
```

### SSL/HTTPS issues

**Error:**
```
Mixed Content: The page was loaded over HTTPS, but requested an insecure resource
```

**Solutions:**

1. **Set up nginx with SSL:**
   ```nginx
   server {
       listen 443 ssl;
       server_name tiles.your-domain.com;
       
       ssl_certificate /etc/ssl/certs/your-cert.pem;
       ssl_certificate_key /etc/ssl/private/your-key.pem;
       
       location / {
           proxy_pass http://localhost:8080;
           proxy_set_header Host $host;
           proxy_set_header X-Real-IP $remote_addr;
       }
   }
   ```

2. **Use Let's Encrypt:**
   ```bash
   certbot --nginx -d tiles.your-domain.com
   ```

## Getting Help

If you're still experiencing issues:

1. **Check logs:**
   ```bash
   make logs
   ```

2. **Verify setup:**
   ```bash
   docker compose ps
   docker compose config
   ```

3. **Create an issue:**
   - Visit: https://github.com/p-s-dev/OpenStreetMap-PostGIS-TileServer/issues
   - Include:
     - Error messages
     - Logs output
     - System information (OS, Docker version, RAM)
     - Region size and PBF file size
     - Steps to reproduce

## Diagnostic Commands

```bash
# Check all services
docker compose ps

# View logs
docker compose logs --tail=100 postgis
docker compose logs --tail=100 tileserver
docker compose logs --tail=100 api

# Check disk space
df -h

# Check memory usage
free -h

# Check Docker stats
docker stats

# Verify network
docker compose exec api ping tileserver
docker compose exec api curl http://tileserver:8080/

# Check database
docker compose exec postgis psql -U osm -d osm -c "\dt"
docker compose exec postgis psql -U osm -d osm -c "SELECT COUNT(*) FROM osm_roads;"

# Test tiles
curl -I http://localhost:8080/tiles/0/0/0.pbf
curl -I http://localhost:8080/tiles/0/0/0.png

# Check MBTiles
ls -lh data/*.mbtiles
sqlite3 data/us-latest.mbtiles "SELECT name, value FROM metadata;"
sqlite3 data/us-latest.mbtiles "SELECT zoom_level, COUNT(*) FROM tiles GROUP BY zoom_level;"
```
