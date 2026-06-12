#!/bin/bash

# Docker Cleanup Script
# Usage: ./docker_cleanup.sh [OPTIONS]

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
DRY_RUN=false
FORCE=false
VERBOSE=false
CLEANUP_CONTAINERS=false
CLEANUP_IMAGES=false
CLEANUP_VOLUMES=false
CLEANUP_NETWORKS=false
CLEANUP_ALL=false
KEEP_RECENT_DAYS=7
SHOW_UNUSED=false
INTERACTIVE=false

usage() {
    cat << EOF
Docker Cleanup Script

Usage: $0 [OPTIONS]

OPTIONS:
    -h, --help              Show this help message
    -d, --dry-run           Show what would be deleted without actually deleting
    -f, --force             Force deletion without confirmation
    -v, --verbose           Verbose output
    -i, --interactive       Interactive mode - ask before each deletion

    --containers            Clean up stopped containers
    --images                Clean up unused images
    --volumes               Clean up unused volumes
    --networks              Clean up unused networks
    --all                   Clean up everything (containers, images, volumes, networks)

    --keep-recent=DAYS      Keep images created in the last N days (default: 7)
    --show-unused           Only show unused resources, don't delete

    --nuclear               Remove everything not actively used (use with caution!)

EXAMPLES:
    $0 --show-unused                    # Show what can be cleaned up
    $0 --dry-run --all                  # Show what would be deleted
    $0 --images --containers            # Clean up images and containers
    $0 --all --keep-recent=14           # Clean up everything except recent images
    $0 --nuclear --force                # Remove everything (dangerous!)
EOF
}

log() {
    if [[ $VERBOSE == true ]]; then
        echo -e "${BLUE}[INFO]${NC} $1"
    fi
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

confirm() {
    if [[ $FORCE == true ]]; then
        return 0
    fi

    local message="$1"
    echo -e "${YELLOW}$message${NC}"
    read -p "Continue? (y/N): " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]]
}

show_running_containers() {
    echo -e "\n${BLUE}=== Currently Running Containers ===${NC}"
    docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
}

show_all_containers() {
    echo -e "\n${BLUE}=== All Containers ===${NC}"
    docker ps -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.CreatedAt}}"
}

show_images_detailed() {
    echo -e "\n${BLUE}=== All Images ===${NC}"
    docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.CreatedAt}}\t{{.Size}}"
}

find_unused_images() {
    echo -e "\n${BLUE}=== Unused Images ===${NC}"

    # Get all image IDs that are used by containers
    local used_images; used_images=$(docker ps -a --format "{{.Image}}" | sort | uniq)

    # Get all images
    docker images --format "{{.Repository}}:{{.Tag}} {{.ID}} {{.CreatedAt}} {{.Size}}" | while read repo_tag id created size; do
        if [[ "$repo_tag" != "<none>:<none>" ]]; then
            # Check if this image is used
            local is_used=false
            while IFS= read -r used_image; do
                if [[ "$used_image" == "$repo_tag" ]] || [[ "$used_image" == "$id" ]]; then
                    is_used=true
                    break
                fi
            done <<< "$used_images"

            if [[ $is_used == false ]]; then
                echo "UNUSED: $repo_tag ($id) - Created: $created - Size: $size"
            fi
        fi
    done
}

find_old_images() {
    echo -e "\n${BLUE}=== Images Older Than $KEEP_RECENT_DAYS Days ===${NC}"
    local cutoff_date; cutoff_date=$(date -d "$KEEP_RECENT_DAYS days ago" +%s)

    docker images --format "{{.Repository}}:{{.Tag}} {{.ID}} {{.CreatedAt}}" | while read repo_tag id created_str; do
        # Convert created date to timestamp (this is approximate)
        if command -v gdate >/dev/null 2>&1; then
            # macOS
            local created_ts; created_ts=$(gdate -d "$created_str" +%s 2>/dev/null || echo "0")
        else
            # Linux
            local created_ts; created_ts=$(date -d "$created_str" +%s 2>/dev/null || echo "0")
        fi

        if [[ $created_ts -lt $cutoff_date ]] && [[ $created_ts -gt 0 ]]; then
            echo "OLD: $repo_tag ($id) - Created: $created_str"
        fi
    done
}

cleanup_containers() {
    echo -e "\n${BLUE}=== Cleaning Up Containers ===${NC}"

    local stopped_containers; stopped_containers=$(docker ps -aq --filter "status=exited")

    if [[ -z "$stopped_containers" ]]; then
        echo "No stopped containers to remove."
        return
    fi

    if [[ $DRY_RUN == true ]]; then
        echo "Would remove stopped containers:"
        docker ps -a --filter "status=exited" --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"
        return
    fi

    if [[ $INTERACTIVE == true ]]; then
        docker ps -a --filter "status=exited" --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"
        if ! confirm "Remove these stopped containers?"; then
            return
        fi
    fi

    docker container prune -f
    success "Removed stopped containers"
}

cleanup_images() {
    echo -e "\n${BLUE}=== Cleaning Up Images ===${NC}"

    if [[ $DRY_RUN == true ]]; then
        echo "Would remove unused images:"
        docker images --filter "dangling=true"
        find_unused_images
        return
    fi

    if [[ $INTERACTIVE == true ]]; then
        find_unused_images
        if ! confirm "Remove unused images?"; then
            return
        fi
    fi

    # Remove dangling images first
    docker image prune -f

    # Remove unused images
    docker image prune -a -f

    success "Removed unused images"
}

cleanup_volumes() {
    echo -e "\n${BLUE}=== Cleaning Up Volumes ===${NC}"

    if [[ $DRY_RUN == true ]]; then
        echo "Would remove unused volumes:"
        docker volume ls --filter "dangling=true"
        return
    fi

    if [[ $INTERACTIVE == true ]]; then
        docker volume ls --filter "dangling=true"
        if ! confirm "Remove unused volumes?"; then
            return
        fi
    fi

    docker volume prune -f
    success "Removed unused volumes"
}

cleanup_networks() {
    echo -e "\n${BLUE}=== Cleaning Up Networks ===${NC}"

    if [[ $DRY_RUN == true ]]; then
        echo "Would remove unused networks:"
        docker network ls --filter "dangling=true"
        return
    fi

    if [[ $INTERACTIVE == true ]]; then
        docker network ls --filter "dangling=true"
        if ! confirm "Remove unused networks?"; then
            return
        fi
    fi

    docker network prune -f
    success "Removed unused networks"
}

nuclear_cleanup() {
    warn "NUCLEAR OPTION: This will remove ALL unused Docker resources!"

    if [[ $DRY_RUN == true ]]; then
        echo "Would run: docker system prune -a -f"
        return
    fi

    if ! confirm "Are you ABSOLUTELY sure you want to remove everything?"; then
        echo "Aborted."
        return
    fi

    docker system prune -a -f
    success "Nuclear cleanup completed"
}

main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -f|--force)
                FORCE=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -i|--interactive)
                INTERACTIVE=true
                shift
                ;;
            --containers)
                CLEANUP_CONTAINERS=true
                shift
                ;;
            --images)
                CLEANUP_IMAGES=true
                shift
                ;;
            --volumes)
                CLEANUP_VOLUMES=true
                shift
                ;;
            --networks)
                CLEANUP_NETWORKS=true
                shift
                ;;
            --all)
                CLEANUP_ALL=true
                shift
                ;;
            --keep-recent=*)
                KEEP_RECENT_DAYS="${1#*=}"
                shift
                ;;
            --show-unused)
                SHOW_UNUSED=true
                shift
                ;;
            --nuclear)
                nuclear_cleanup
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done

    # Check if Docker is running
    if ! docker info >/dev/null 2>&1; then
        error "Docker is not running or not accessible"
        exit 1
    fi

    # Show current state
    if [[ $VERBOSE == true ]] || [[ $SHOW_UNUSED == true ]]; then
        show_running_containers
        show_all_containers
        show_images_detailed
        find_unused_images
        find_old_images
    fi

    # If only showing unused, exit here
    if [[ $SHOW_UNUSED == true ]]; then
        exit 0
    fi

    # If no specific cleanup options, show usage
    if [[ $CLEANUP_ALL == false ]] && [[ $CLEANUP_CONTAINERS == false ]] && \
       [[ $CLEANUP_IMAGES == false ]] && [[ $CLEANUP_VOLUMES == false ]] && \
       [[ $CLEANUP_NETWORKS == false ]]; then
        echo "No cleanup options specified. Use --help for usage information."
        echo "Try: $0 --show-unused to see what can be cleaned up"
        exit 1
    fi

    # Perform cleanup operations
    if [[ $CLEANUP_ALL == true ]]; then
        cleanup_containers
        cleanup_images
        cleanup_volumes
        cleanup_networks
    else
        [[ $CLEANUP_CONTAINERS == true ]] && cleanup_containers
        [[ $CLEANUP_IMAGES == true ]] && cleanup_images
        [[ $CLEANUP_VOLUMES == true ]] && cleanup_volumes
        [[ $CLEANUP_NETWORKS == true ]] && cleanup_networks
    fi

    if [[ $DRY_RUN == false ]]; then
        echo -e "\n${GREEN}Cleanup completed!${NC}"
        echo "Current Docker disk usage:"
        docker system df
    fi
}

# Run main function with all arguments
main "$@"


## Make executable
#chmod +x docker_cleanup.sh
#
## See what can be cleaned up
#./docker_cleanup.sh --show-unused
#
## Dry run to see what would be deleted
#./docker_cleanup.sh --dry-run --all
#
## Clean up just images and containers
#./docker_cleanup.sh --images --containers
#
## Interactive cleanup (asks before each operation)
#./docker_cleanup.sh --interactive --all
#
## Nuclear option (removes everything unused)
#./docker_cleanup.sh --nuclear --force
#
## Clean up everything but keep recent images
#./docker_cleanup.sh --all --keep-recent=14