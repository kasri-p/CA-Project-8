# Loop-based Fibonacci benchmark results

## Program and expected state

Both processors start with `$t0 = 0`, `$t1 = 1`, and `$a0 = 8`. Each loop
iteration calculates the next Fibonacci value, shifts the pair, and decrements
the counter:

```mips
loop:
    add     $v0, $t0, $t1
    add     $t0, $t1, $zero
    add     $t1, $v0, $zero
    addi    $a0, $a0, -1
    bnez    $a0, loop
    nop
```

After eight iterations:

- `$a0 = 0`
- `$t0 = 21`
- `$t1 = 34`
- `$v0 = 34`

Starting from `0, 1`, the value `34` is the tenth displayed term. It is `F(9)`
with conventional zero-based Fibonacci indexing.

## Scheduling difference

The no-forwarding program uses the manual NOP schedule supplied for the
benchmark:

- three NOPs after initialization;
- three NOPs between `add $t0, ...` and `add $t1, $v0, ...`;
- four NOPs between decrementing `$a0` and `bnez`.

Those are ten static data-NOP positions. The seven NOPs inside the loop execute
eight times, while the three initialization NOPs execute once, for a total of
`3 + (7 x 8) = 59` dynamic data NOPs.

The forwarding version removes every data-hazard NOP. The NOP after `bnez` and
the NOP after `j` remain control delay slots and are not counted as data NOPs.

The final circuit writes the register file on the falling clock edge. This lets
the next loop iteration read a value written back during the same clock cycle;
without that timing, the tight loop would read the previous Fibonacci pair.

## Measured results

Each test starts counting after the program has been loaded and reset has been
released. It stops on the first cycle where `$a0 = 0` and `$t1 = 34`, then also
checks `$t0` and `$v0`. The infinite `done` loop is therefore not included in
the measurement.

| Processor | Dynamic data NOPs | Total cycles | Result |
|---|---:|---:|---:|
| With forwarding | 0 | 54 | 34 |
| Without forwarding | 59 | 109 | 34 |

```text
Cycle reduction: 109 - 54 = 55 cycles
Speedup:         109 / 54 = 2.02x
Reduction:        55 / 109 = 50.5%
```

Both benchmarks assert their expected register state and cycle count. A change
that alters either correctness or timing therefore ends with a `FAILED_...`
marker.

## Files

- `programs/fibonacci/fibonacci_forwarding.asm`: loop without data NOPs
- `programs/fibonacci/fibonacci_forwarding.hex`: forwarding ROM words
- `programs/fibonacci/fibonacci_no_forwarding.asm`: manually scheduled loop
- `programs/fibonacci/fibonacci_no_forwarding.hex`: baseline ROM words
- `tests/benchmark/tb_fibonacci_forwarding.v`: forwarding measurement
- `tests/benchmark/tb_fibonacci_no_forwarding.v`: baseline measurement

Run both self-checking benchmarks from the `Project` folder:

```sh
./scripts/run_benchmarks.sh --local
./scripts/run_benchmarks.sh --docker
```

After both simulations pass, the runner prints the forwarding and
no-forwarding cycle counts as a side-by-side bar comparison, followed by the
cycles saved, percentage reduction, and speedup. The same clean output is
written to `build/fibonacci_cycle_summary.txt` for use in the project report.

The full macOS Terminal-window capture is available at
`docs/screenshots/fibonacci_full_terminal.png`.

Successful runs end with:

```text
ACCEPTED_FIBONACCI_FORWARDING
ACCEPTED_FIBONACCI_NO_FORWARDING
```
