#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COURSE_ROOT="$(cd "$PROJECT_ROOT/.." && pwd)"
RESULT_DIR="$PROJECT_ROOT/build"

MODE="local"
case "${1:-}" in
    ""|--local)
        ;;
    --docker)
        MODE="docker"
        ;;
    *)
        printf 'Usage: %s [--local|--docker]\n' "$0" >&2
        exit 2
        ;;
esac

if [[ "$MODE" == "docker" ]]; then
    if ! command -v docker >/dev/null 2>&1; then
        printf 'ERROR: Docker is not installed or is not on PATH.\n' >&2
        exit 1
    fi

    if ! docker info >/dev/null 2>&1; then
        printf 'ERROR: Docker Desktop/daemon is not running.\n' >&2
        exit 1
    fi

    if ! docker image inspect myenv:latest >/dev/null 2>&1; then
        printf 'ERROR: Docker image myenv:latest is missing. Run ./scripts/build_docker.sh first.\n' >&2
        exit 1
    fi
fi

run_test() {
    local testbench_path="$1"

    if [[ "$MODE" == "docker" ]]; then
        (
            cd "$COURSE_ROOT"
            bash ./judge.sh \
                Project/Full_Pipeline/pipeline_v5.circ \
                "Project/$testbench_path"
        )
    else
        (
            cd "$PROJECT_ROOT"
            ../scripts/synth_valid.sh \
                Full_Pipeline/pipeline_v5.circ \
                "$testbench_path"
        )
    fi
}

require_marker() {
    local log_file="$1"
    local marker="$2"

    if ! grep -q "$marker" "$log_file"; then
        printf 'ERROR: expected marker %s was not produced.\n' "$marker" >&2
        exit 1
    fi
}

mkdir -p "$RESULT_DIR"

printf '\nForwarding-only test\n'
run_test tests/extended/tb_forwarding.v \
    | tee "$RESULT_DIR/forwarding_test.log"
require_marker "$RESULT_DIR/forwarding_test.log" ACCEPTED_FORWARDING_ONLY

printf '\nLoad-use hazard test\n'
run_test tests/extended/tb_hazard.v \
    | tee "$RESULT_DIR/hazard_test.log"
require_marker "$RESULT_DIR/hazard_test.log" ACCEPTED_LW_LOAD_USE_STALL

printf '\nCombined forwarding and hazard test\n'
run_test tests/extended/tb_hazard_forwarding.v \
    | tee "$RESULT_DIR/hazard_forwarding_test.log"
require_marker \
    "$RESULT_DIR/hazard_forwarding_test.log" \
    ACCEPTED_FORWARDING_AND_LOAD_USE

printf '\nEXTENDED TEST SUMMARY\n'
printf '%-36s %s\n' 'Forwarding paths' PASS
printf '%-36s %s\n' 'Load-use hazard and one-cycle stall' PASS
printf '%-36s %s\n' 'Combined forwarding and load-use' PASS
printf '\nLogs saved under: %s\n' "$RESULT_DIR"
