# Loop-based Fibonacci benchmark for the processor without forwarding.
# This is the manually scheduled version with data-hazard NOPs.
# Eight iterations produce the tenth displayed term: $t1 = 34.

        addi    $sp, $zero, 2048
        add     $t0, $zero, $zero
        addi    $t1, $zero, 1
        addi    $a0, $zero, 8
        nop
        nop
        nop

loop:
        add     $v0, $t0, $t1
        add     $t0, $t1, $zero
        nop
        nop
        nop
        add     $t1, $v0, $zero

        addi    $a0, $a0, -1
        nop
        nop
        nop
        nop
        bnez    $a0, loop
        nop

done:
        j       done
        nop
