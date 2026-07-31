# Project 8 scenario 1: direct EX/MEM forwarding to ALU input A.
# Expected result: $t0 = 13, $t3 = 9, with no stall.

addi $t1, $zero, 10
addi $t2, $zero, 3
addi $t4, $zero, 4
addi $s0, $zero, 101
addi $s1, $zero, 102
addi $s2, $zero, 103
add  $t0, $t1, $t2
sub  $t3, $t0, $t4
