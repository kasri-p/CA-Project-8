`timescale 1ns/1ps

// Project 8 - required scenario 1:
//   add $t0, $t1, $t2
//   sub $t3, $t0, $t4
//
// The second instruction must receive $t0 from EX/MEM (ForwardA = 2'b10)
// and must not stall.  The forwarding control signals are not top-level
// processor ports, so this test verifies their architectural effect: the
// dependent result must be correct and commits must remain consecutive.
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
    integer fail_flag;

    localparam integer PROGRAM_LEN = 8;
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

        // Initialize all operands far enough ahead of the required pair.
        instructions[0] = enc_i(6'b001000, 5'd0, 5'd9,  16'd10);
        // addi $t1, $zero, 10
        instructions[1] = enc_i(6'b001000, 5'd0, 5'd10, 16'd3);
        // addi $t2, $zero, 3
        instructions[2] = enc_i(6'b001000, 5'd0, 5'd12, 16'd4);
        // addi $t4, $zero, 4
        instructions[3] = enc_i(6'b001000, 5'd0, 5'd16, 16'd101);
        instructions[4] = enc_i(6'b001000, 5'd0, 5'd17, 16'd102);
        instructions[5] = enc_i(6'b001000, 5'd0, 5'd18, 16'd103);

        // Required EX-hazard pair.  There is deliberately no NOP.
        instructions[6] = enc_r(5'd9, 5'd10, 5'd8, 6'b100000);
        // add $t0, $t1, $t2       ; $t0 = 13
        instructions[7] = enc_r(5'd8, 5'd12, 5'd11, 6'b100010);
        // sub $t3, $t0, $t4       ; forwarded 13 - 4 = 9

        // Load data memory followed by instruction memory.
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

        while ((commit_no < PROGRAM_LEN) && (cycle_no < MAX_CYCLES)) begin
            #2;
            cycle_no = cycle_no + 1;

            if (InstDone === 1'b1) begin
                $display(
                    "commit=%0d cycle=%0d instruction=0x%08x",
                    commit_no, cycle_no, instructions[commit_no]
                );

                if ((last_commit_cycle >= 0) &&
                    ((cycle_no - last_commit_cycle) != 1)) begin
                    fail_flag = 1;
                    $display("ERROR: unexpected stall before commit %0d", commit_no);
                end

                if ((commit_no == 6) && (R[8] !== 32'd13)) begin
                    fail_flag = 1;
                    $display("ERROR: producer result $t0=%0d, expected 13", R[8]);
                end

                if (commit_no == 7) begin
                    if (R[11] !== 32'd9) begin
                        fail_flag = 1;
                        $display(
                            "ERROR: dependent result $t3=0x%08x, expected 9",
                            R[11]
                        );
                    end
                    else begin
                        $display(
                            "PASS: EX/MEM value reached ALU input A with no stall"
                        );
                    end
                end

                last_commit_cycle = cycle_no;
                commit_no = commit_no + 1;
            end
        end

        if (commit_no != PROGRAM_LEN) begin
            fail_flag = 1;
            $display(
                "ERROR: TIMEOUT: only %0d of %0d instructions committed",
                commit_no, PROGRAM_LEN
            );
        end

        if (fail_flag) begin
            $display("FAILED_SCENARIO_1_EX_HAZARD");
            $finish(1);
        end
        else begin
            $display("ACCEPTED_SCENARIO_1_EX_HAZARD");
            $finish(0);
        end
    end
endmodule
