#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COURSE_ROOT="$(cd "$PROJECT_ROOT/.." && pwd)"
RESULT_DIR="$PROJECT_ROOT/build"
NO_FORWARDING_ALIAS="$RESULT_DIR/no_forwarding_circuit"

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
    local circuit_path="$1"
    local testbench_path="$2"

    if [[ "$MODE" == "docker" ]]; then
        (
            cd "$COURSE_ROOT"
            bash ./judge.sh \
                "Project/$circuit_path" \
                "Project/$testbench_path"
        )
    else
        (
            cd "$PROJECT_ROOT"
            ../scripts/synth_valid.sh \
                "$circuit_path" \
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

no_forwarding_circuit="Pipeline/pipeline.circ"
if [[ "$MODE" == "local" ]]; then
    if [[ -e "$NO_FORWARDING_ALIAS" && ! -L "$NO_FORWARDING_ALIAS" ]]; then
        printf 'ERROR: expected %s to be a generated symbolic link.\n' \
            "$NO_FORWARDING_ALIAS" >&2
        exit 1
    fi
    ln -sfn "../Pipeline" "$NO_FORWARDING_ALIAS"
    no_forwarding_circuit="build/no_forwarding_circuit/pipeline.circ"
fi

printf '\nProject 8 scenario 1: EX hazard\n'
run_test \
    Full_Pipeline/pipeline_v5.circ \
    tests/scenarios/tb_scenario1_ex_hazard.v \
    | tee "$RESULT_DIR/scenario1_ex_hazard.log"
require_marker \
    "$RESULT_DIR/scenario1_ex_hazard.log" \
    ACCEPTED_SCENARIO_1_EX_HAZARD

printf '\nProject 8 scenario 2: load-use hazard\n'
run_test \
    Full_Pipeline/pipeline_v5.circ \
    tests/scenarios/tb_scenario2_load_use.v \
    | tee "$RESULT_DIR/scenario2_load_use.log"
require_marker \
    "$RESULT_DIR/scenario2_load_use.log" \
    ACCEPTED_SCENARIO_2_LOAD_USE

printf '\nNo-forwarding scenario reference\n'
run_test \
    "$no_forwarding_circuit" \
    tests/scenarios/tb_scenarios_no_forwarding.v \
    | tee "$RESULT_DIR/scenarios_no_forwarding.log"
require_marker \
    "$RESULT_DIR/scenarios_no_forwarding.log" \
    ACCEPTED_SCENARIOS_WITHOUT_FORWARDING
