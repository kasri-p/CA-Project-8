# Project 8 scenario 2: load-use hazard.
# Data memory word 16 must contain 37.
# Expected result: exactly one hardware stall, $t0 = 37, $t2 = 42.

addi $t1, $zero, 16
addi $t0, $zero, 10
addi $t3, $zero, 5
addi $s0, $zero, 123
lw   $t0, 0($t1)
add  $t2, $t0, $t3
