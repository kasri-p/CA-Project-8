`timescale 1ns/1ps

// Reference run for Pipeline/pipeline.circ.
// The same two Project 8 dependencies are made correct with software NOPs.
// This is a functional/cycle-count baseline, not a forwarding-unit test.
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
    integer scenario1_cycle;
    integer scenario2_cycle;
    integer fail_flag;

    localparam integer PROGRAM_LEN = 20;
    localparam integer MAX_CYCLES  = 50;

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
        scenario1_cycle = -1;
        scenario2_cycle = -1;
        fail_flag = 0;

        for (i = 0; i < 512; i = i + 1) begin
            instructions[i] = 32'b0;
            data_mem[i] = 32'b0;
        end

        data_mem[16] = 32'd37;

        // Operand setup for scenario 1.
        instructions[0] = enc_i(6'b001000, 5'd0, 5'd9,  16'd10);
        instructions[1] = enc_i(6'b001000, 5'd0, 5'd10, 16'd3);
        instructions[2] = enc_i(6'b001000, 5'd0, 5'd12, 16'd4);
        instructions[3] = enc_i(6'b001000, 5'd0, 5'd16, 16'd101);
        instructions[4] = enc_i(6'b001000, 5'd0, 5'd17, 16'd102);
        instructions[5] = enc_i(6'b001000, 5'd0, 5'd18, 16'd103);

        instructions[6] = enc_r(5'd9, 5'd10, 5'd8, 6'b100000);
        // add $t0, $t1, $t2
        instructions[7] = 32'b0;
        instructions[8] = 32'b0;
        instructions[9] = 32'b0;
        // Three software NOPs replace the EX/MEM bypass.  This baseline's
        // register file is read before the same-edge WB update is visible.
        instructions[10] = enc_r(5'd8, 5'd12, 5'd11, 6'b100010);
        // sub $t3, $t0, $t4

        // Operand setup for scenario 2.  Three independent instructions
        // separate the base-address producer from lw.
        instructions[11] = enc_i(6'b001000, 5'd0, 5'd9, 16'd16);
        instructions[12] = enc_i(6'b001000, 5'd0, 5'd11, 16'd5);
        instructions[13] = enc_i(6'b001000, 5'd0, 5'd19, 16'd77);
        instructions[14] = enc_i(6'b001000, 5'd0, 5'd20, 16'd88);

        instructions[15] = enc_i(6'b100011, 5'd9, 5'd8, 16'd0);
        // lw $t0, 0($t1)
        instructions[16] = 32'b0;
        instructions[17] = 32'b0;
        instructions[18] = 32'b0;
        // Three software NOPs wait for the load to write back.
        instructions[19] = enc_r(5'd8, 5'd11, 5'd10, 6'b100000);
        // add $t2, $t0, $t3

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
        #8;

        // NOP visibility through InstDone is implementation-specific, so the
        // reference test waits for architectural results instead of treating
        // each InstDone pulse as an instruction index.
        while ((cycle_no < MAX_CYCLES) && (scenario2_cycle < 0)) begin
            #2;
            cycle_no = cycle_no + 1;

            if (InstDone === 1'b1)
                commit_no = commit_no + 1;

            if ((R[11] === 32'd9) && (scenario1_cycle < 0)) begin
                scenario1_cycle = cycle_no;
                $display(
                    "PASS: no-forwarding EX dependency completed at cycle %0d",
                    cycle_no
                );
            end

            if ((R[10] === 32'd42) && (scenario2_cycle < 0)) begin
                scenario2_cycle = cycle_no;
                $display(
                    "PASS: no-forwarding load dependency completed at cycle %0d",
                    cycle_no
                );
            end
        end

        if (scenario1_cycle < 0) begin
            fail_flag = 1;
            $display("ERROR: scenario 1 result was never produced");
        end

        if (scenario2_cycle < 0) begin
            fail_flag = 1;
            $display("ERROR: scenario 2 result was never produced");
        end

        if (R[8] !== 32'd37) begin
            fail_flag = 1;
            $display("ERROR: final loaded $t0=%0d, expected 37", R[8]);
        end

        if (commit_no != PROGRAM_LEN) begin
            fail_flag = 1;
            $display(
                "ERROR: observed %0d commits, expected %0d",
                commit_no, PROGRAM_LEN
            );
        end

        $display(
            "INFO: final t0=%0d t2=%0d t3=%0d",
            R[8], R[10], R[11]
        );
        $display(
            "INFO: reference used six software NOPs; InstDone pulses=%0d",
            commit_no
        );

        if (fail_flag) begin
            $display("FAILED_SCENARIOS_WITHOUT_FORWARDING");
            $finish(1);
        end
        else begin
            $display("ACCEPTED_SCENARIOS_WITHOUT_FORWARDING");
            $finish(0);
        end
    end
endmodule
