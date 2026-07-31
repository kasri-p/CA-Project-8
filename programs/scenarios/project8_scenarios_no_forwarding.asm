# The two required scenarios scheduled for the processor without forwarding.
# Data memory word 16 must contain 37.

addi $t1, $zero, 10
addi $t2, $zero, 3
addi $t4, $zero, 4
addi $s0, $zero, 101
addi $s1, $zero, 102
addi $s2, $zero, 103
add  $t0, $t1, $t2
nop
nop
nop
sub  $t3, $t0, $t4

addi $t1, $zero, 16
addi $t3, $zero, 5
addi $s3, $zero, 77
addi $s4, $zero, 88
lw   $t0, 0($t1)
nop
nop
nop
add  $t2, $t0, $t3
