# Contributing to OpenStreetMap PostGIS TileServer

Thank you for your interest in contributing! This document provides guidelines for contributing to the project.

## Getting Started

1. **Fork the repository** on GitHub
2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/OpenStreetMap-PostGIS-TileServer.git
   cd OpenStreetMap-PostGIS-TileServer
   ```
3. **Create a feature branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```

## Development Setup

### Using VS Code Dev Container (Recommended)

1. Open the project in VS Code
2. Click "Reopen in Container" when prompted
3. All dependencies are pre-installed

### Local Development

Requirements:
- Docker & Docker Compose
- Node.js 20+ (for API development)
- Make

```bash
# Install API dependencies
cd api && npm install

# Start services
make up

# Run tests (when available)
npm test
```

## Making Changes

### Code Style

- **Shell scripts**: Follow [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- **TypeScript**: Use Prettier and ESLint (configurations will be added)
- **YAML/JSON**: Use 2-space indentation
- **Makefile**: Use tabs for indentation

### Testing Your Changes

Before submitting a PR:

1. **Validate configuration files:**
   ```bash
   # Docker Compose
   docker compose config --quiet
   
   # JSON files
   cat tileserver/config.json | python3 -m json.tool
   
   # YAML files
   python3 -c "import yaml; yaml.safe_load(open('openmaptiles/mapping.yaml'))"
   
   # Shell scripts
   bash -n scripts/import_imposm.sh
   ```

2. **Test the workflow:**
   ```bash
   # Use a small region for testing
   wget https://download.geofabrik.de/north-america/us/rhode-island-latest.osm.pbf -O data/us-latest.osm.pbf
   
   # Run the pipeline
   make all
   
   # Verify tiles are accessible
   curl -I http://localhost:8080/tiles/0/0/0.pbf
   ```

3. **Run linters:**
   ```bash
   # TypeScript
   cd api && npm run build
   
   # Shellcheck (if available)
   shellcheck scripts/*.sh
   ```

## Types of Contributions

### Bug Fixes

1. Search [existing issues](https://github.com/p-s-dev/OpenStreetMap-PostGIS-TileServer/issues)
2. Create a new issue if needed, describing:
   - Steps to reproduce
   - Expected behavior
   - Actual behavior
   - Environment details
3. Reference the issue in your PR

### Features

1. Open an issue to discuss the feature first
2. Wait for maintainer feedback
3. Implement with tests and documentation
4. Submit PR referencing the issue

### Documentation

Documentation improvements are always welcome:
- Fix typos
- Clarify instructions
- Add examples
- Improve troubleshooting guide

### Examples

Add examples for:
- Different mapping libraries (Leaflet, OpenLayers, etc.)
- Cloud deployment (AWS, GCP, Azure)
- CI/CD pipelines
- Advanced configurations

## Pull Request Process

1. **Update documentation** if you've changed functionality
2. **Add tests** if applicable
3. **Update CHANGELOG.md** (if it exists) with your changes
4. **Ensure all checks pass**:
   - Docker Compose validates
   - JSON/YAML are valid
   - Shell scripts have no syntax errors
   - TypeScript compiles

5. **Write a clear PR description**:
   ```markdown
   ## Description
   Brief description of changes
   
   ## Motivation
   Why is this change needed?
   
   ## Testing
   How did you test this?
   
   ## Checklist
   - [ ] Documentation updated
   - [ ] Tests added/updated
   - [ ] Configurations validated
   - [ ] Tested locally
   ```

6. **Request review** from maintainers

## Commit Messages

Use clear, descriptive commit messages:

```bash
# Good
git commit -m "Add support for PMTiles export"
git commit -m "Fix CORS headers in API proxy"
git commit -m "Update README with troubleshooting steps"

# Not as good
git commit -m "Fix bug"
git commit -m "Update stuff"
git commit -m "WIP"
```

### Commit Message Format

```
<type>: <subject>

<body>

<footer>
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation only
- `style`: Code style changes (formatting)
- `refactor`: Code refactoring
- `test`: Adding tests
- `chore`: Maintenance tasks

**Example:**
```
feat: Add support for custom TileServer GL styles

- Add styles directory with basic.json example
- Update config.json to reference custom styles
- Add documentation for creating custom styles

Closes #123
```

## Code Review Process

1. Maintainers will review your PR
2. Address any requested changes
3. Once approved, maintainers will merge

## Community Guidelines

- Be respectful and inclusive
- Help others learn and grow
- Give constructive feedback
- Credit others for their work

## Questions?

- Open an [issue](https://github.com/p-s-dev/OpenStreetMap-PostGIS-TileServer/issues)
- Check [existing discussions](https://github.com/p-s-dev/OpenStreetMap-PostGIS-TileServer/discussions)

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

## Attribution

Contributors will be acknowledged in:
- GitHub contributors page
- CONTRIBUTORS.md (if created)
- Release notes

Thank you for contributing! 🎉
