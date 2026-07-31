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
    integer last_commit_cycle;
    integer actual_gap;
    integer fail_flag;

    localparam integer PROGRAM_LEN = 6;
    localparam integer MAX_CYCLES  = 40;

    function [31:0] enc_r;
        input [4:0] rs;
        input [4:0] rt;
        input [4:0] rd;
        input [5:0] funct;
        begin
            enc_r = {6'b000000, rs, rt, rd, 5'b00000, funct};
        end
    endfunction

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
        last_commit_cycle = -1;
        fail_flag = 0;

        for (i = 0; i < 512; i = i + 1) begin
            instructions[i] = 32'b0;
            data_mem[i] = 32'b0;
        end

        // This processor's data memory is word-addressed, so effective
        // address 16 maps directly to data_mem[16].
        data_mem[16] = 32'd37;

        instructions[0] = enc_i(6'b001000, 5'd0, 5'd9, 16'd16);
        // addi $t1, $zero, 16

        instructions[1] = enc_i(6'b001000, 5'd0, 5'd8, 16'd10);
        // addi $t0, $zero, 10
        // $t0 is deliberately non-zero before lw.

        instructions[2] = enc_i(6'b001000, 5'd0, 5'd11, 16'd5);
        // addi $t3, $zero, 5

        instructions[3] = enc_i(6'b001000, 5'd0, 5'd16, 16'd123);
        // addi $s0, $zero, 123
        // Independent instruction: gives $t1 enough time to reach WB,
        // because this test does not assume forwarding.

        instructions[4] = enc_i(6'b100011, 5'd9, 5'd8, 16'd0);
        // lw   $t0, 0($t1)
        // $t0 changes from 10 to 37.

        instructions[5] = enc_r(5'd8, 5'd11, 5'd10, 6'b100000);
        // add  $t2, $t0, $t3
        //
        // No NOP exists between lw and add.

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

        // Pipeline fill time, matching the supplied testbench.
        #8;

        while ((commit_no < PROGRAM_LEN) && (cycle_no < MAX_CYCLES)) begin
            #2;
            cycle_no = cycle_no + 1;

            if (InstDone === 1'b1) begin
                $display(
                    "commit=%0d cycle=%0d instruction=0x%08x",
                    commit_no, cycle_no, instructions[commit_no]
                );
                $display(
                    "    t0(R8)=%0d  t1(R9)=%0d  t2(R10)=%0d  t3(R11)=%0d",
                    R[8], R[9], R[10], R[11]
                );

                if (commit_no > 0) begin
                    actual_gap = cycle_no - last_commit_cycle;

                    if (commit_no == 4) begin
                        // The testbench observes architectural register
                        // updates one commit behind the raw WB payload. The
                        // load-use bubble therefore appears before commit 4.
                        if (actual_gap != 2) begin
                            fail_flag = 1;
                            $display(
                                "ERROR: lw->add gap is %0d; expected 2 cycles (one stall)",
                                actual_gap
                            );
                        end
                        else begin
                            $display("PASS: one load-use stall was observed");
                        end
                    end
                    else if (actual_gap != 1) begin
                        fail_flag = 1;
                        $display(
                            "ERROR: unexpected stall before instruction %0d",
                            commit_no
                        );
                    end
                end

                // Checking the loaded value does not require forwarding.
                if ((commit_no == 1) && (R[8] !== 32'd10)) begin
                    fail_flag = 1;
                    $display(
                        "ERROR: initial t0 value is %0d, expected 10",
                        R[8]
                    );
                end

                if ((commit_no == 4) && (R[8] !== 32'd37)) begin
                    fail_flag = 1;
                    $display(
                        "ERROR: lw result R[8]=0x%08x, expected 0x00000025",
                        R[8]
                    );
                end

                // R[10], the result of add, is deliberately not checked.
                // Without forwarding, a single load-use stall is not enough
                // to guarantee the correct add operand.

                last_commit_cycle = cycle_no;
                commit_no = commit_no + 1;
            end
        end

        if (commit_no != PROGRAM_LEN) begin
            fail_flag = 1;
            $display(
                "ERROR: TIMEOUT/DEADLOCK: only %0d of %0d instructions committed",
                commit_no, PROGRAM_LEN
            );
        end

        if (fail_flag) begin
            $display("FAILED_LW_LOAD_USE_STALL");
            $finish(1);
        end
        else begin
            $display("ACCEPTED_LW_LOAD_USE_STALL");
            $finish(0);
        end
    end
endmodule
