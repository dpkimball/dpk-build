#!/usr/bin/env bash
set -euo pipefail
_SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_SCRIPTS_DIR/../env.sh"
source "$_SCRIPTS_DIR/../common.sh"
[ -f "$PWD/env.sh" ] && source "$PWD/env.sh"

log_info "📦 Building Rust crate..."

PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
CARGO_TOML="${CARGO_TOML:-$PROJECT_ROOT/Cargo.toml}"
TARGET_DIR="${TARGET_DIR:-$PROJECT_ROOT/target}"
DIST_DIR="${DIST_DIR:-$PROJECT_ROOT/dist}"

if [[ ! -f "$CARGO_TOML" ]]; then
  log_error "❌ Not in a Rust project directory (Cargo.toml not found)"
  exit 1
fi

log_info "📁 Working from: $PROJECT_ROOT"
mkdir -p "$DIST_DIR"

list_packages() {
  python3 - "$PROJECT_ROOT" <<'PY'
import json, subprocess, sys
root = sys.argv[1]
meta = json.loads(
    subprocess.check_output(
        ["cargo", "metadata", "--format-version", "1", "--no-deps"],
        cwd=root,
        text=True,
    )
)
ids = set(meta["workspace_members"])
for p in meta["packages"]:
    if p["id"] not in ids:
        continue
    # Cargo: publish = false → empty list. Skip those (e.g. xtask).
    if p.get("publish") == []:
        continue
    print(p["name"])
PY
}

publish_one() {
  local name="$1"
  log_info "📤 Publishing ${name} to Cargo registry ${CARGO_REGISTRY}..."
  set +e
  local output status
  output=$(cargo publish -p "$name" --registry "${CARGO_REGISTRY}" --allow-dirty 2>&1)
  status=$?
  set -e
  if [[ $status -eq 0 ]]; then
    echo "$output"
    log_info "✅ Publish complete for ${name}"
    return 0
  fi
  if echo "$output" | grep -qiE 'already exists|previously uploaded|duplicate version'; then
    log_info "⚠️  ${name} already on registry ${CARGO_REGISTRY}, skipping (this is OK)"
    return 0
  fi
  if echo "$output" | grep -qiE 'path dependenc'; then
    log_info "⚠️  skip Kellnr publish for ${name}: path deps remain (use registry = \"dpk\")"
    return 0
  fi
  echo "$output" >&2
  log_error "❌ Publish failed for ${name}"
  return 1
}

package_one() {
  local name="$1"
  log_info "📦 Packaging ${name}..."
  set +e
  local output status
  output=$(cargo package -p "$name" --allow-dirty --no-verify 2>&1)
  status=$?
  set -e
  if [[ $status -ne 0 ]]; then
    if echo "$output" | grep -qiE 'path dependenc'; then
      log_info "⚠️  skip package ${name}: path deps remain (use registry = \"dpk\")"
      return 0
    fi
    echo "$output" >&2
    log_error "❌ Package failed for ${name}"
    return 1
  fi
  echo "$output"
  local crate_file
  crate_file=$(find "$TARGET_DIR/package" -name "${name}-*.crate" | head -n1 || true)
  if [[ -n "$crate_file" ]]; then
    cp "$crate_file" "$DIST_DIR/"
    log_info "✅ Built: $(basename "$crate_file")"
  fi
}

# Bash 3.2 compatible (macOS /bin/bash). mapfile/readarray require Bash 4+.
PACKAGES=()
while IFS= read -r _pkg || [[ -n "${_pkg:-}" ]]; do
  [[ -z "${_pkg:-}" ]] && continue
  PACKAGES+=("$_pkg")
done < <(list_packages)
if [[ ${#PACKAGES[@]} -eq 0 ]]; then
  log_error "❌ No publishable Cargo packages in this workspace"
  exit 1
fi
log_info "🔍 Packages: ${PACKAGES[*]}"

log_info "🧹 Cleaning old artifacts..."
rm -rf "$TARGET_DIR/package"

for name in "${PACKAGES[@]}"; do
  package_one "$name"
done

if [[ "${PUBLISH_CRATE:-false}" == "true" ]]; then
  "$_SCRIPTS_DIR/cargo-publish-registry.sh" >/dev/null || {
    log_error "❌ Publish refused (set CARGO_REGISTRY=dpk; crates.io is blocked)"
    exit 1
  }
  # Repeat until every package is published or skipped: dependents may need
  # earlier members on the registry first.
  remaining=("${PACKAGES[@]}")
  for _round in $(seq 1 "${#PACKAGES[@]}"); do
    [[ ${#remaining[@]} -eq 0 ]] && break
    next=()
    for name in "${remaining[@]}"; do
      if publish_one "$name"; then
        :
      else
        next+=("$name")
      fi
    done
    if [[ ${#next[@]} -eq "${#remaining[@]}" ]]; then
      log_error "❌ No progress publishing: ${remaining[*]}"
      exit 1
    fi
    if [[ ${#next[@]} -eq 0 ]]; then
      remaining=()
    else
      remaining=("${next[@]}")
    fi
  done
else
  log_info "💡 To publish to Kellnr registry dpk, set PUBLISH_CRATE=true CARGO_REGISTRY=dpk"
fi

log_info "🕓 Finished at $(date)"
