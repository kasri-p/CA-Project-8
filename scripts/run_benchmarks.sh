#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COURSE_ROOT="$(cd "$PROJECT_ROOT/.." && pwd)"
RESULT_DIR="$PROJECT_ROOT/build"
FORWARDING_LOG="$RESULT_DIR/fibonacci_forwarding.log"
NO_FORWARDING_LOG="$RESULT_DIR/fibonacci_no_forwarding.log"
SUMMARY_FILE="$RESULT_DIR/fibonacci_cycle_summary.txt"
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

extract_result_field() {
    local log_file="$1"
    local wanted_field="$2"

    awk -v wanted="$wanted_field" '
        index($0, "BENCHMARK_RESULT") {
            for (i = 1; i <= NF; i++) {
                split($i, part, "=")
                if (part[1] == wanted)
                    value = part[2]
            }
        }
        END {
            gsub(/[^0-9.-]/, "", value)
            print value
        }
    ' "$log_file"
}

print_cycle_summary() {
    local forwarding_cycles="$1"
    local no_forwarding_cycles="$2"
    local result_value="$3"

    awk \
        -v forwarding="$forwarding_cycles" \
        -v baseline="$no_forwarding_cycles" \
        -v result="$result_value" '
        function cycle_bar(value, maximum, width, output, count, i) {
            count = int((value / maximum) * width + 0.5)
            output = ""
            for (i = 0; i < count; i++)
                output = output "#"
            for (i = count; i < width; i++)
                output = output " "
            return output
        }
        BEGIN {
            saved = baseline - forwarding
            reduction = (saved / baseline) * 100
            speedup = baseline / forwarding

            print ""
            print "FIBONACCI CYCLE COMPARISON"
            print "---------------------------------------------------------------"
            printf "With forwarding       %3d cycles |%s|\n", \
                forwarding, cycle_bar(forwarding, baseline, 40)
            printf "Without forwarding    %3d cycles |%s|\n", \
                baseline, cycle_bar(baseline, baseline, 40)
            print "---------------------------------------------------------------"
            printf "Cycles saved:          %3d\n", saved
            printf "Cycle reduction:       %5.1f%%\n", reduction
            printf "Speedup:               %5.2fx\n", speedup
            printf "Final Fibonacci value: %3d\n", result
        }
    '
}

mkdir -p "$RESULT_DIR"

# The shared synthesis helper does not quote circuit paths internally. Use a
# generated no-space alias while still targeting the circuit in the original
# "Pipeline" directory.
if [[ -e "$NO_FORWARDING_ALIAS" && ! -L "$NO_FORWARDING_ALIAS" ]]; then
    printf 'ERROR: expected %s to be a generated symbolic link.\n' \
        "$NO_FORWARDING_ALIAS" >&2
    exit 1
fi
ln -sfn "../Pipeline" "$NO_FORWARDING_ALIAS"

printf '\nFibonacci(10): processor with forwarding\n'
run_test \
    Full_Pipeline/pipeline_v5.circ \
    tests/benchmark/tb_fibonacci_forwarding.v \
    | tee "$FORWARDING_LOG"

printf '\nFibonacci(10): processor without forwarding\n'
run_test \
    build/no_forwarding_circuit/pipeline.circ \
    tests/benchmark/tb_fibonacci_no_forwarding.v \
    | tee "$NO_FORWARDING_LOG"

if ! grep -q 'ACCEPTED_FIBONACCI_FORWARDING' "$FORWARDING_LOG"; then
    printf 'ERROR: forwarding Fibonacci benchmark did not pass.\n' >&2
    exit 1
fi

if ! grep -q 'ACCEPTED_FIBONACCI_NO_FORWARDING' "$NO_FORWARDING_LOG"; then
    printf 'ERROR: no-forwarding Fibonacci benchmark did not pass.\n' >&2
    exit 1
fi

forwarding_cycles="$(extract_result_field "$FORWARDING_LOG" total_cycles)"
no_forwarding_cycles="$(extract_result_field "$NO_FORWARDING_LOG" total_cycles)"
forwarding_result="$(extract_result_field "$FORWARDING_LOG" fib_term_10)"
no_forwarding_result="$(extract_result_field "$NO_FORWARDING_LOG" fib_term_10)"

if [[ -z "$forwarding_cycles" || -z "$no_forwarding_cycles" ]]; then
    printf 'ERROR: could not read cycle counts from benchmark output.\n' >&2
    exit 1
fi

if [[ "$forwarding_result" != "$no_forwarding_result" ]]; then
    printf 'ERROR: benchmark results differ (%s versus %s).\n' \
        "$forwarding_result" "$no_forwarding_result" >&2
    exit 1
fi

print_cycle_summary \
    "$forwarding_cycles" \
    "$no_forwarding_cycles" \
    "$forwarding_result" \
    | tee "$SUMMARY_FILE"

printf '\nCycle summary saved to: %s\n' "$SUMMARY_FILE"
