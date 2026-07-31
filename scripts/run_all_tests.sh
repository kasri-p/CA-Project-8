#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${1:---local}"

case "$MODE" in
    --local|--docker)
        ;;
    *)
        printf 'Usage: %s [--local|--docker]\n' "$0" >&2
        exit 2
        ;;
esac

"$PROJECT_ROOT/scripts/run_required_tests.sh" "$MODE"
"$PROJECT_ROOT/scripts/run_extended_tests.sh" "$MODE"
"$PROJECT_ROOT/scripts/run_benchmarks.sh" "$MODE"
