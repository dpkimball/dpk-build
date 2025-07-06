# Keepsake Scripts

Reusable Docker build/test scripts.

## Usage

```bash
export KEEPSAKE_PROJECT_ROOT="$HOME/PycharmProjects"
export KEEPSAKE_SCRIPTS_ROOT="$KEEPSAKE_PROJECT_ROOT/keepsake-scripts"
export KEEPSAKE_COMPOSE_PROJECT_ROOT="$KEEPSAKE_PROJECT_ROOT/keepsake"
export PYPI_PACKAGE_DIR="$KEEPSAKE_PROJECT_ROOT/keepsake-pypi/keepsake-pypi/package

# Set up project-specific overrides
cp .env.example .env.build

# Then run build
./scripts/build.sh

# Skip tests or clean up with env vars
SKIP_TESTS=true CLEAN=true ./scripts/build.sh
```

## Requirements
- bash
- docker
- pytest (if using Python tests)
- biome or prettier (for linting)
