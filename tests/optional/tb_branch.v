`timescale 1ns/1ps

module tb;
    reg clk, rst, Jen;
    reg [31:0] instructions [0:511];
    reg [31:0] data_mem    [0:511];

    reg  [31:0] Jin;
    wire [31:0] Jout;
    wire        InstDone;
    wire [31:0] R [0:31];

    assign R[0] = 32'b0;

    integer i;
    integer cycle_no;
    integer commit_no;
    integer branch_commit_cycle;
    integer target_commit_cycle;
    integer fail_flag;

    localparam integer MAX_CYCLES = 60;

    function [31:0] enc_i;
        input [5:0]  opcode;
        input [4:0]  rs;
        input [4:0]  rt;
        input [15:0] imm;
        begin
            enc_i = {opcode, rs, rt, imm};
        end
    endfunction

    main _main (
        .clk(clk),
        .rst(rst),
        .Jen(Jen),
        .Jin(Jin),
        .Jout(Jout),
        .InstDone(InstDone),
        .R1(R[1]),   .R2(R[2]),   .R3(R[3]),   .R4(R[4]),
        .R5(R[5]),   .R6(R[6]),   .R7(R[7]),   .R8(R[8]),
        .R9(R[9]),   .R10(R[10]), .R11(R[11]), .R12(R[12]),
        .R13(R[13]), .R14(R[14]), .R15(R[15]), .R16(R[16]),
        .R17(R[17]), .R18(R[18]), .R19(R[19]), .R20(R[20]),
        .R21(R[21]), .R22(R[22]), .R23(R[23]), .R24(R[24]),
        .R25(R[25]), .R26(R[26]), .R27(R[27]), .R28(R[28]),
        .R29(R[29]), .R30(R[30]), .R31(R[31])
    );

    initial begin
        clk = 1'b0;
        forever #1 clk = ~clk;
    end

    initial begin
        rst = 1'b1;
        Jen = 1'b0;
        Jin = 32'b0;
        cycle_no = 0;
        commit_no = 0;
        branch_commit_cycle = -1;
        target_commit_cycle = -1;
        fail_flag = 0;

        for (i = 0; i < 512; i = i + 1) begin
            instructions[i] = 32'b0;
            data_mem[i] = 32'b0;
        end

        // ------------------------------------------------------------
        // Values used by the branch are prepared well in advance.
        // Therefore there is no RAW/load-use hazard near the branch.
        // ------------------------------------------------------------
        instructions[0] = enc_i(6'b001000, 5'd0, 5'd8, 16'd5);
        // addi $t0, $zero, 5

        instructions[1] = enc_i(6'b001000, 5'd0, 5'd9, 16'd7);
        // addi $t1, $zero, 7

        instructions[2] = enc_i(6'b001000, 5'd0, 5'd16, 16'd101);
        // addi $s0, $zero, 101

        instructions[3] = enc_i(6'b001000, 5'd0, 5'd17, 16'd102);
        // addi $s1, $zero, 102

        instructions[4] = enc_i(6'b001000, 5'd0, 5'd18, 16'd103);
        // addi $s2, $zero, 103

        // Taken branch:
        // target = (branch index + 1) + immediate = 6 + 3 = 9.
        instructions[5] = enc_i(6'b000101, 5'd8, 5'd9, 16'd3);
        // bne $t0, $t1, target     ; taken because 5 != 7

        // This may behave as the architectural delay slot in the existing
        // processor. Its value is not used to decide pass/fail.
        instructions[6] = enc_i(6'b001000, 5'd0, 5'd2, 16'd11);
        // addi $v0, $zero, 11

        // Wrong path: neither instruction is allowed to change its register.
        instructions[7] = enc_i(6'b001000, 5'd0, 5'd5, 16'd99);
        // addi $a1, $zero, 99      ; must be flushed

        instructions[8] = enc_i(6'b001000, 5'd0, 5'd6, 16'd99);
        // addi $a2, $zero, 99      ; must be flushed

        // Branch target.
        instructions[9] = enc_i(6'b001000, 5'd0, 5'd3, 16'd42);
        // target: addi $v1, $zero, 42

        instructions[10] = enc_i(6'b001000, 5'd0, 5'd4, 16'd43);
        // addi $a0, $zero, 43

        // A non-taken branch, also with operands ready and no hazard.
        instructions[11] = enc_i(6'b000101, 5'd8, 5'd8, 16'd2);
        // bne $t0, $t0, skip       ; not taken

        instructions[12] = enc_i(6'b001000, 5'd0, 5'd7, 16'd55);
        // addi $a3, $zero, 55      ; must execute

        instructions[13] = enc_i(6'b001000, 5'd0, 5'd19, 16'd66);
        // addi $s3, $zero, 66      ; completion marker

        // Load memories through the same interface as the original testbench.
        #8 rst = 1'b0;
        Jen = 1'b1;

        for (i = 0; i < 512; i = i + 1) begin
            Jin = data_mem[511-i];
            #2;
        end

        for (i = 0; i < 512; i = i + 1) begin
            Jin = instructions[511-i];
            #2;
        end

        Jen = 1'b0;

        rst = 1'b1;
        #2 rst = 1'b0;

        // Pipeline fill time.
        #8;

        while ((R[19] !== 32'd66) && (cycle_no < MAX_CYCLES)) begin
            #2;
            cycle_no = cycle_no + 1;

            if (InstDone === 1'b1) begin
                $display(
                    "commit=%0d cycle=%0d  t0=%0d t1=%0d v1=%0d a1=%0d a2=%0d",
                    commit_no, cycle_no, R[8], R[9], R[3], R[5], R[6]
                );

                // The first five ADDI instructions commit before the branch.
                if (commit_no == 5) begin
                    branch_commit_cycle = cycle_no;
                    $display("INFO: taken branch committed at cycle %0d", cycle_no);
                end

                // Detect the first cycle in which the target instruction
                // becomes architecturally visible.
                if ((R[3] === 32'd42) && (target_commit_cycle < 0)) begin
                    target_commit_cycle = cycle_no;
                    $display("INFO: branch target committed at cycle %0d", cycle_no);
                end

                commit_no = commit_no + 1;
            end
        end

        if (R[19] !== 32'd66) begin
            fail_flag = 1;
            $display("ERROR: TIMEOUT before reaching the completion marker");
        end

        // Taken branch must reach its target.
        if (R[3] !== 32'd42) begin
            fail_flag = 1;
            $display("ERROR: taken branch did not reach target; R3=%0d", R[3]);
        end

        if (R[4] !== 32'd43) begin
            fail_flag = 1;
            $display("ERROR: instruction after target failed; R4=%0d", R[4]);
        end

        // Wrong-path instructions must be flushed.
        if (R[5] !== 32'd0) begin
            fail_flag = 1;
            $display("ERROR: first wrong-path instruction committed; R5=%0d", R[5]);
        end

        if (R[6] !== 32'd0) begin
            fail_flag = 1;
            $display("ERROR: second wrong-path instruction committed; R6=%0d", R[6]);
        end

        // The non-taken branch must continue sequentially.
        if (R[7] !== 32'd55) begin
            fail_flag = 1;
            $display("ERROR: non-taken branch skipped sequential code; R7=%0d", R[7]);
        end

        if ((branch_commit_cycle < 0) || (target_commit_cycle < 0)) begin
            fail_flag = 1;
            $display("ERROR: could not measure branch-to-target timing");
        end
        else if ((target_commit_cycle - branch_commit_cycle) != 2) begin
            fail_flag = 1;
            $display(
                "ERROR: branch-to-target distance=%0d cycles; expected 2 for ID resolution",
                target_commit_cycle - branch_commit_cycle
            );
        end
        else begin
            $display("PASS: branch target appeared with ID-stage timing");
        end

        if (fail_flag) begin
            $display("FAILED_BONUS_BRANCH_ID_NO_HAZARD");
            $finish(1);
        end
        else begin
            $display("ACCEPTED_BONUS_BRANCH_ID_NO_HAZARD");
            $finish(0);
        end
    end
endmodule
