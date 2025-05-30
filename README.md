# Keepsake Scripts

Reusable Docker build/test scripts.

## Usage

```bash
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
