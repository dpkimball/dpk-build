# Keepsake Scripts

This directory contains shared build scripts and utilities for the Keepsake ecosystem.

## Build System Overview

The Keepsake ecosystem uses a standardized build process across all projects. Each project has its own `make b` command that handles the complete build and deployment pipeline.

## Command B Setup

### What is "Command B"?

Each Keepsake project has a `make b` target that:
1. **Sources local environment**: Runs `./bin/build.sh` which sources the project's `env.sh` file
2. **Updates versions**: Automatically updates internal package versions (e.g., `keepsake-services` from 0.0.10 to 0.0.11)
3. **Builds wheel**: Creates a Python wheel and uploads it to the local PyPI server
4. **Docker build**: Builds the Docker image with proper environment variables
5. **Kubernetes deploy**: Deploys to Kubernetes using Helm

### Why Use Command B?

- **Environment consistency**: Each project has its own `env.sh` with specific settings
- **Version management**: Automatically keeps internal dependencies up-to-date
- **Local PyPI integration**: Uses the local PyPI server for internal packages
- **Proper build context**: Sources the right environment variables for Docker builds

## Project Structure

Each Keepsake project follows this structure:

```
project-name/
├── bin/
│   └── build.sh          # Main build script
├── env.sh                # Project-specific environment variables
├── pyproject.toml        # Python project configuration
├── Dockerfile            # Container definition
├── Makefile              # Project makefile with 'b' target
└── README.md
```

## Build Scripts

### `build.sh`
The main build script that:
- Sources `env.sh` for environment variables
- Updates internal package versions
- Builds and uploads Python wheels to local PyPI
- Builds Docker images
- Deploys to Kubernetes

### `build-docker-image.sh`
Generic Docker build script (legacy - use `make b` instead)

### `common.sh`
Shared utilities and functions used across build scripts

## Usage

### Building a Project

```bash
# From within a project directory
make b
```

### Building from Infrastructure

```bash
# From keepsake-infra directory
make dev-build-brain-viewer    # Uses: cd ../keepsake-brain-viewer && make b
make dev-build-langgraph       # Uses: cd ../keepsake-brain && make b
```

## Environment Variables

Each project's `env.sh` file should define:
- `KEEPSAKE_PROJECT_ROOT`: Root directory of all Keepsake projects
- `KEEPSAKE_SCRIPTS_ROOT`: Path to this scripts directory
- Project-specific variables (ports, hosts, etc.)

## Local PyPI Server

The build process uses a local PyPI server for internal packages:
- **URL**: `http://localhost:8080`
- **Purpose**: Hosts internal packages like `keepsake-services`, `memory-graph-client`
- **Authentication**: Uses admin credentials from environment

## Docker Build Process

1. **Environment Setup**: Sources project's `env.sh`
2. **Dependency Resolution**: Uses `uv` for Python package management
3. **Wheel Building**: Creates Python wheels for local packages
4. **Image Building**: Builds Docker image with proper environment
5. **Deployment**: Deploys to Kubernetes using Helm

## Best Practices

1. **Always use `make b`**: Don't use generic build scripts directly
2. **Keep env.sh updated**: Ensure project-specific variables are current
3. **Version management**: Let the build process handle version updates
4. **Local PyPI**: Ensure local PyPI server is running before builds
5. **Environment consistency**: Each project should have its own `env.sh`

## Troubleshooting

### Common Issues

1. **Version mismatches**: Run `make b` to update internal package versions
2. **Environment variables**: Check that `env.sh` is properly sourced
3. **Local PyPI**: Ensure PyPI server is running on localhost:8080
4. **Docker builds**: Check that environment variables are passed correctly

### Debug Commands

```bash
# Check environment variables
source env.sh && env | grep KEEPSAKE

# Check local PyPI packages
curl http://localhost:8080/simple/

# Check Docker build context
docker build --no-cache -t test-image .
```

## Integration with Infrastructure

The `keepsake-infra` Makefile has been updated to use `make b` for all project builds:

- `dev-build-brain-viewer`: Uses `cd ../keepsake-brain-viewer && make b`
- `dev-build-langgraph`: Uses `cd ../keepsake-brain && make b`

This ensures consistent builds across the entire ecosystem.

## Environment-Specific Deployments

### Dagster Components

Dagster (data orchestration platform) is part of the Keepsake ecosystem but has environment-specific deployment strategies:

- **DEV Environment**: Dagster components are **disabled** (`enabled: false` in `values-dev.yaml`)
  - Reason: Dagster performs better on Linux Intel chips than macOS ARM
  - Components: webserver and daemon are not deployed
  - PostgreSQL is still available for other services

- **QA Environment**: Dagster components are **enabled** (`enabled: true` in `values-qa.yaml`)
  - Reason: Linux Intel environment provides optimal performance
  - Components: Full Dagster stack (webserver, daemon, PostgreSQL)
  - Story-runner pipelines are available and configured

### Story-Runner Integration

The Dagster chart is configured for the story-runner project with commented-out workspace entries for:
- `dagster_story_runner_media_pipeline`
- `dagster-story-maker-service`
- `dagster-text-decipher-service`
- `dagster-image-decipher-service`
- `dagster-audio-decipher-service`
- `dagster-video-decipher-service`

These components are built separately and integrated when deployed to QA.

### Build Commands

Dagster build commands are now available for development:

**From keepsake-infra:**
- `make dev-build-dagster-webserver` - Build and deploy Dagster webserver
- `make dev-build-dagster-daemon` - Build and deploy Dagster daemon  
- `make dev-build-dagster` - Build both components

**From story-runner/dagster:**
- `make b-webserver` - Build webserver Docker image
- `make b-daemon` - Build daemon Docker image
- `make b` - Build both components

**Note:** While Dagster is disabled by default in dev (for performance reasons), developers can now build and test Dagster components locally when needed.

## Contributing

When adding new projects to the Keepsake ecosystem:

1. Create project directory with standard structure
2. Add `env.sh` with project-specific variables
3. Add `bin/build.sh` that sources `env.sh`
4. Add `make b` target to project Makefile
5. Update `keepsake-infra` Makefile with new build commands

## Related Documentation

- [Keepsake Ecosystem Overview](../ECOSYSTEM_OVERVIEW.md)
- Individual project READMEs in their respective directories
- [Keepsake Infrastructure](../keepsake-infra/README.md)