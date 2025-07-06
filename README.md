# Keepsake Scripts

Reusable Docker build/test scripts.

## Usage

```bash
alias dps="docker ps"
alias dst="docker stats"
alias dpsa="docker ps -a"
alias dimgs="docker images"
alias dup="docker compose up -d"
alias ddown="docker compose down"
alias dstart="docker compose start"
alias dstop="docker compose stop"
alias dwatch="docker compose watch"
alias dbp="docker builder prune -af"
alias dip="docker image prune -af"
alias dsp="docker system prune -af --volumes"
alias kc="dbp && dip" # keepsake clean
alias b="./bin/build.sh"
alias j="./bin/jupyter.sh"
alias u="./bin/uv_sync.sh"
alias d="deactivate"
alias s="source .venv/bin/activate"
alias ds="d && s"
alias sb="./build.sh"
alias check_ks_size="sudo du -sh /System/Volumes/Data/* 2>/dev/null | sort -hr | head -n 20"
alias kubectl="minikube kubectl --"
alias treek="tree -I '__pycache__|*.pyc|*.pyo|.venv|.DS_Store|dist|build|*.egg-info|htmlcov'"
alias sz="source ~/.zshrc"

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
