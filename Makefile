.PHONY: help up import mbtiles serve all logs clean nuke indexes stop

# Load environment variables
include .env
export

help: ## Display this help message
	@echo "OpenStreetMap PostGIS TileServer - Available targets:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "Quick start:"
	@echo "  1. Download us-latest.osm.pbf to ./data/"
	@echo "  2. Run 'make all' to set up everything"
	@echo "  3. Access tiles at http://localhost:8080/tiles/{z}/{x}/{y}.pbf"

up: ## Start PostgreSQL database
	@echo "Starting PostgreSQL..."
	docker compose up -d postgis
	@echo "Waiting for PostgreSQL to be ready..."
	@sleep 5
	docker compose exec postgis pg_isready -U $(POSTGRES_USER) -d $(POSTGRES_DB) || sleep 10
	@echo "PostgreSQL is ready!"

import: ## Import OSM data using configured importer (imposm or osm2pgsql)
	@if [ ! -f "./data/us-latest.osm.pbf" ]; then \
		echo "ERROR: PBF file not found at ./data/us-latest.osm.pbf"; \
		echo "Please download it from https://download.geofabrik.de/north-america-latest.osm.pbf"; \
		exit 1; \
	fi
	@echo "Starting import using $(IMPORTER)..."
	@if [ "$(IMPORTER)" = "imposm" ]; then \
		docker compose run --rm imposm /scripts/import_imposm.sh; \
	else \
		docker compose run --rm imposm /scripts/import_osm2pgsql.sh; \
	fi
	@echo "Import completed!"

mbtiles: ## Generate MBTiles from PostGIS data
	@echo "Generating MBTiles at $(MBTILES_PATH)..."
	docker compose run --rm openmaptiles-tools /scripts/generate_mbtiles.sh
	@echo "MBTiles generation completed!"
	@ls -lh ./data/*.mbtiles

serve: ## Start TileServer GL and API
	@echo "Starting TileServer GL and API..."
	docker compose --profile serve up -d tileserver api
	@echo ""
	@echo "Services started!"
	@echo "  TileServer GL: http://localhost:$(TILESERVER_PORT)/"
	@echo "  API (CORS-enabled): http://localhost:$(API_PORT)/tiles/{z}/{x}/{y}.pbf"
	@echo ""

all: up import mbtiles serve ## Run complete pipeline: setup DB, import data, generate tiles, start servers

stop: ## Stop all running services
	@echo "Stopping all services..."
	docker compose --profile serve --profile import --profile mbtiles down
	@echo "Services stopped."

logs: ## Tail logs from all services
	docker compose --profile serve logs -f

indexes: ## Create spatial indexes (mainly for osm2pgsql workflow)
	@echo "Creating spatial indexes..."
	@docker compose exec -T postgis psql -U $(POSTGRES_USER) -d $(POSTGRES_DB) -c "\
		CREATE INDEX IF NOT EXISTS idx_planet_osm_point_way ON planet_osm_point USING GIST (way); \
		CREATE INDEX IF NOT EXISTS idx_planet_osm_line_way ON planet_osm_line USING GIST (way); \
		CREATE INDEX IF NOT EXISTS idx_planet_osm_polygon_way ON planet_osm_polygon USING GIST (way); \
		CREATE INDEX IF NOT EXISTS idx_planet_osm_roads_way ON planet_osm_roads USING GIST (way);"
	@echo "Indexes created!"

clean: ## Remove generated files but keep database
	@echo "Cleaning generated files..."
	rm -f ./data/*.mbtiles
	rm -rf ./data/imposm3cache
	rm -rf ./data/cache
	@echo "Clean complete. Database preserved."

nuke: stop ## Remove everything including database volumes
	@echo "WARNING: This will delete all data including the PostgreSQL database!"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		docker compose --profile serve --profile import --profile mbtiles down -v; \
		rm -f ./data/*.mbtiles; \
		rm -rf ./data/imposm3cache; \
		rm -rf ./data/cache; \
		echo "Everything has been removed!"; \
	else \
		echo "Cancelled."; \
	fi
