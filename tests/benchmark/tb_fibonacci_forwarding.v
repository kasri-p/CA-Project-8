`timescale 1ns/1ps

// Loop-based Fibonacci benchmark for the processor with forwarding.
// The program calculates eight new terms from F(0)=0 and F(1)=1. Therefore
// the final value is the tenth displayed term, 34, in $t1 (R9).
//
// No data-hazard NOPs are used. The NOPs after bne and j are control delay
// slots and are present in both benchmark versions.
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
    integer done_cycle;
    integer inst_done_pulses;
    integer fail_flag;

    localparam integer MAX_CYCLES = 200;
    localparam integer EXPECTED_TOTAL_CYCLES = 54;

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

    function [31:0] enc_j;
        input [25:0] target;
        begin
            enc_j = {6'b000010, target};
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
        done_cycle = -1;
        inst_done_pulses = 0;
        fail_flag = 0;

        for (i = 0; i < 512; i = i + 1) begin
            instructions[i] = 32'b0;
            data_mem[i] = 32'b0;
        end

        instructions[0] = enc_i(6'b001000, 5'd0, 5'd29, 16'd2048);
        // addi $sp, $zero, 2048
        instructions[1] = enc_r(5'd0, 5'd0, 5'd8, 6'b100000);
        // add  $t0, $zero, $zero
        instructions[2] = enc_i(6'b001000, 5'd0, 5'd9, 16'd1);
        // addi $t1, $zero, 1
        instructions[3] = enc_i(6'b001000, 5'd0, 5'd4, 16'd8);
        // addi $a0, $zero, 8

        // loop (word address 4)
        instructions[4] = enc_r(5'd8, 5'd9, 5'd2, 6'b100000);
        // add  $v0, $t0, $t1
        instructions[5] = enc_r(5'd9, 5'd0, 5'd8, 6'b100000);
        // add  $t0, $t1, $zero
        instructions[6] = enc_r(5'd2, 5'd0, 5'd9, 6'b100000);
        // add  $t1, $v0, $zero
        instructions[7] = enc_i(6'b001000, 5'd4, 5'd4, 16'hffff);
        // addi $a0, $a0, -1
        instructions[8] = enc_i(6'b000101, 5'd4, 5'd0, 16'hfffb);
        // bne  $a0, $zero, loop   ; 4 - (8 + 1) = -5
        instructions[9] = 32'b0;
        // nop                     ; branch delay slot

        // done (word address 10)
        instructions[10] = enc_j(26'd10);
        // j done
        instructions[11] = 32'b0;
        // nop                     ; jump delay slot

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

        while ((done_cycle < 0) && (cycle_no < MAX_CYCLES)) begin
            #2;
            cycle_no = cycle_no + 1;

            if (InstDone === 1'b1)
                inst_done_pulses = inst_done_pulses + 1;

            if ((R[4] === 32'd0) && (R[9] === 32'd34))
                done_cycle = cycle_no;
        end

        if (done_cycle < 0) begin
            fail_flag = 1;
            $display("ERROR: Fibonacci loop did not finish within %0d cycles", MAX_CYCLES);
        end

        if (R[2] !== 32'd34) begin
            fail_flag = 1;
            $display("ERROR: final $v0=%0d, expected 34", R[2]);
        end

        if (R[8] !== 32'd21) begin
            fail_flag = 1;
            $display("ERROR: final $t0=%0d, expected 21", R[8]);
        end

        if (R[9] !== 32'd34) begin
            fail_flag = 1;
            $display("ERROR: final $t1=%0d, expected 34", R[9]);
        end

        if (done_cycle !== EXPECTED_TOTAL_CYCLES) begin
            fail_flag = 1;
            $display(
                "ERROR: forwarding benchmark took %0d cycles, expected %0d",
                done_cycle, EXPECTED_TOTAL_CYCLES
            );
        end

        $display(
            "BENCHMARK_RESULT mode=forwarding fib_term_10=%0d data_nops=0 total_cycles=%0d inst_done_pulses=%0d",
            R[9], done_cycle, inst_done_pulses
        );

        if (fail_flag) begin
            $display("FAILED_FIBONACCI_FORWARDING");
            $finish(1);
        end
        else begin
            $display("ACCEPTED_FIBONACCI_FORWARDING");
            $finish(0);
        end
    end
endmodule
