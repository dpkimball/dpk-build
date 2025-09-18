# Rust Support in Keepsake Scripts

This document describes the Rust support added to the keepsake-scripts project for building and deploying Rust applications, specifically designed for the memory-graph-service.

## Overview

The Rust support provides standardized scripts for:
- Building Rust projects with Docker support
- Building multi-architecture Docker images
- Launching containers in development environments
- Integration with existing keepsake-scripts patterns

## Scripts

### `rust_build.sh`
Builds a Rust project with optional linting, testing, and Docker image building.

**Usage:**
```bash
# Basic build
./rust_build.sh

# Clean build
./rust_build.sh --clean

# Skip certain steps
SKIP_LINT=true ./rust_build.sh
SKIP_TESTS=true ./rust_build.sh
SKIP_DOCKER_IMAGE=true ./rust_build.sh
```

**Features:**
- Validates it's running in a Rust project (checks for Cargo.toml)
- Runs clippy linting
- Runs tests
- Builds release binary
- Optionally builds Docker image

### `rust_docker_build.sh`
Builds a multi-architecture Docker image for Rust projects.

**Usage:**
```bash
# Build with defaults
./rust_docker_build.sh

# Clean build
CLEAN=true ./rust_docker_build.sh

# Custom image name
IMAGE_NAME=my-rust-app ./rust_docker_build.sh
```

**Features:**
- Multi-architecture builds (linux/amd64, linux/arm64)
- Automatic tagging with date stamps
- Container testing
- Configurable via environment variables

### `rust_launch_dev.sh`
Launches a Rust container in the development environment.

**Usage:**
```bash
# Launch with defaults
./rust_launch_dev.sh

# Clean launch (stops existing container)
CLEAN=true ./rust_launch_dev.sh

# Custom configuration
IMAGE_NAME=my-rust-app CONTAINER_NAME=my-dev ./rust_launch_dev.sh
```

**Features:**
- Automatic environment variable loading from config.env
- Host networking for local development
- Container management (stop/remove existing)
- Logging and status reporting

## Integration with Memory Graph Service

The memory-graph-service Makefile has been updated to integrate with these scripts:

### New Makefile Targets

- `make build-docker` - Build Docker image using keepsake-scripts
- `make launch-dev` - Launch container in dev environment
- `make dev-up` - Build and launch dev environment (recommended)
- `make dev-down` - Stop dev environment
- `make dev-logs` - Show dev container logs
- `make dev-shell` - Open shell in dev container

### Quick Start

```bash
# Navigate to memory-graph-service
cd /path/to/memory-graph-service

# Build and launch dev environment
make dev-up

# View logs
make dev-logs

# Stop when done
make dev-down
```

## Environment Variables

The scripts support various environment variables for configuration:

### Build Configuration
- `IMAGE_NAME` - Docker image name (default: memory-graph-service)
- `CONTAINER_NAME` - Container name for dev launch (default: memory-graph-service-dev)
- `DOCKERFILE_DIR` - Directory containing Dockerfile (default: .)
- `CLEAN` - Clean previous artifacts (default: false)
- `SKIP_LINT` - Skip linting (default: false)
- `SKIP_TESTS` - Skip tests (default: false)
- `SKIP_DOCKER_IMAGE` - Skip Docker build (default: false)

### Runtime Configuration
The launch script automatically loads environment variables from `config.env` if present, and sets defaults for:
- `RUST_LOG` - Log level (default: info)
- `MONGODB_URI` - MongoDB connection string
- `WEAVIATE_BASE_URL` - Weaviate service URL
- `NEO4J_URI` - Neo4j connection string
- `NEO4J_USER` - Neo4j username
- `NEO4J_PASSWORD` - Neo4j password
- `SYNC_ENABLED` - Enable sync (default: true)
- `SYNC_INTERVAL_SECONDS` - Sync interval (default: 60)
- `SYNC_COLLECTIONS` - Collections to sync
- `EMBEDDING_VERSION` - Embedding version

## Architecture Support

The Dockerfile is designed to support multi-architecture builds and is used by both:
- **GitHub Actions**: Currently builds `linux/amd64` only (see `.github/workflows/deploy.yaml`)
- **Local Development**: Can build for both `linux/amd64` and `linux/arm64`

The local build scripts attempt multi-architecture builds but fall back to single-platform builds if not supported by the Docker driver. This solves the issue where GitHub Actions only builds Intel images, allowing local development on Apple Silicon machines.

**Note**: The Dockerfile is shared between GitHub Actions and local development - any changes must be compatible with both environments.

## Troubleshooting

### Scripts Not Found
If you get "Keepsake scripts not found" errors:
1. Ensure keepsake-scripts is in the expected location relative to your project
2. Check the `KEEPSAKE_SCRIPTS_ROOT` environment variable
3. Verify the scripts are executable: `chmod +x rust_*.sh`

### Docker Build Issues
- Ensure Docker Buildx is available: `docker buildx version`
- Check Docker daemon is running
- Verify Dockerfile exists in the project root

### Container Launch Issues
- Ensure the Docker image was built successfully
- Check if port 50051 is already in use
- Verify environment variables are set correctly

## Development Workflow

1. **Initial Setup**: Use `make dev-up` to build and launch
2. **Development**: Make changes to Rust code
3. **Rebuild**: Use `make build-docker` to rebuild image
4. **Relaunch**: Use `make launch-dev` to restart with new image
5. **Debugging**: Use `make dev-logs` and `make dev-shell` for troubleshooting
6. **Cleanup**: Use `make dev-down` when done

This workflow allows for rapid development without relying on GitHub Actions for image builds.
