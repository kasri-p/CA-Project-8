# Project 8 test scenarios

These files implement the two mandatory scenarios on pages 36-37 of the
project brief.  Each forwarding test is isolated and self-checking.

## Scenario 1: EX hazard

The test executes the required consecutive pair:

```mips
add $t0, $t1, $t2
sub $t3, $t0, $t4
```

With `$t1 = 10`, `$t2 = 3`, and `$t4 = 4`, the expected values are `$t0 = 13`
and `$t3 = 9`.  `tests/scenarios/tb_scenario1_ex_hazard.v` also checks that
there is no gap between commits.  Correct data plus no stall demonstrates the
required `EX/MEM -> ALU A` path (`ForwardA = 10`).

## Scenario 2: load-use hazard

The test executes the required consecutive pair:

```mips
lw  $t0, 0($t1)
add $t2, $t0, $t3
```

Data-memory word 16 is initialized to 37, `$t1 = 16`, and `$t3 = 5`.  The
test requires exactly one bubble, then checks `$t0 = 37` and `$t2 = 42`.
This demonstrates the required `MEM/WB -> ALU A` path after the stall
(`ForwardA = 01`).

## No-forwarding reference

`tests/scenarios/tb_scenarios_no_forwarding.v` runs the same dependencies on
`Pipeline/pipeline.circ`.  Because that baseline's
register-file read does not see a same-edge WB update, it inserts three
software NOPs after each producer, six NOPs total, and checks the same results.
This is the baseline that shows the instruction overhead removed by forwarding.

The no-forwarding circuit's ALU library path was changed from a Windows-only
backslash to `/`, so the supplied synthesis script can open it on macOS and
Linux.

## Run

From this `Project` directory:

```sh
./scripts/run_required_tests.sh --local
./scripts/run_required_tests.sh --docker
```

The extended forwarding, load-use hazard, and combined testbenches can be run
through either runner with:

```sh
./scripts/run_extended_tests.sh --local
./scripts/run_extended_tests.sh --docker
```

Their full macOS Terminal-window screenshots are saved under
`docs/screenshots/` as `forwarding_full_terminal.png`,
`hazard_full_terminal.png`, and `hazard_forwarding_full_terminal.png`.

The corresponding assembly and ROM words are under `programs/scenarios/`.
