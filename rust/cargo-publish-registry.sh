#!/usr/bin/env bash
# Resolve cargo publish flags for DPK private crates.
# Never publishes to crates.io. stdout: space-separated flags (or nothing).
# Exit 0 = ok; exit 1 = refused.
set -euo pipefail

if [[ "${PUBLISH_CRATE:-false}" != "true" ]]; then
  echo "PUBLISH_CRATE is not true" >&2
  exit 1
fi

registry="${CARGO_REGISTRY:-}"
if [[ -z "$registry" ]]; then
  echo "PUBLISH_CRATE=true requires CARGO_REGISTRY (use dpk). crates.io is blocked." >&2
  exit 1
fi

case "$registry" in
  crates-io|crates.io)
    echo "Refusing to publish to crates.io. Use CARGO_REGISTRY=dpk (Kellnr)." >&2
    exit 1
    ;;
esac

printf '%s\n' --registry "$registry" --allow-dirty
