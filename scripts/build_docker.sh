#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COURSE_ROOT="$(cd "$PROJECT_ROOT/.." && pwd)"

if [[ ! -f "$COURSE_ROOT/Dockerfile" ]]; then
    printf 'ERROR: Dockerfile not found at %s/Dockerfile\n' "$COURSE_ROOT" >&2
    exit 1
fi

if [[ ! -f "$COURSE_ROOT/judge.sh" ]]; then
    printf 'ERROR: judge.sh not found at %s/judge.sh\n' "$COURSE_ROOT" >&2
    exit 1
fi

cd "$COURSE_ROOT"
"$COURSE_ROOT/scripts/build.sh"
