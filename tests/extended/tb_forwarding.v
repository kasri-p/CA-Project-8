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
    integer fail_flag;

    localparam integer PROGRAM_LEN = 19;
    localparam integer MAX_CYCLES  = 80;

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

    task check_reg;
        input [4:0]  reg_num;
        input [31:0] expected;
        begin
            if (R[reg_num] !== expected) begin
                fail_flag = 1;
                $display(
                    "ERROR: commit=%0d R[%0d]=0x%08x expected=0x%08x",
                    commit_no, reg_num, R[reg_num], expected
                );
            end
        end
    endtask

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

        // Register initialization. The extra independent instructions ensure
        // these values are already in the register file before forwarding
        // scenarios begin. They are real ADDI instructions, not NOPs.
        instructions[0] = enc_i(6'b001000, 5'd0, 5'd9,  16'd10);
        // addi $t1, $zero, 10

        instructions[1] = enc_i(6'b001000, 5'd0, 5'd10, 16'd3);
        // addi $t2, $zero, 3

        instructions[2] = enc_i(6'b001000, 5'd0, 5'd12, 16'd4);
        // addi $t4, $zero, 4

        instructions[3] = enc_i(6'b001000, 5'd0, 5'd16, 16'd101);
        // addi $s0, $zero, 101

        instructions[4] = enc_i(6'b001000, 5'd0, 5'd17, 16'd102);
        // addi $s1, $zero, 102

        instructions[5] = enc_i(6'b001000, 5'd0, 5'd18, 16'd103);
        // addi $s2, $zero, 103

        // Test 1: EX/MEM -> ALU input A, expected ForwardA=2'b10.
        instructions[6] = enc_r(5'd9, 5'd10, 5'd8, 6'b100000);
        // add $t0, $t1, $t2       ; $t0 = 13

        instructions[7] = enc_r(5'd8, 5'd12, 5'd11, 6'b100010);
        // sub $t3, $t0, $t4       ; $t3 = 13 - 4 = 9

        // Test 2: EX/MEM -> ALU input B, expected ForwardB=2'b10.
        instructions[8] = enc_r(5'd9, 5'd10, 5'd13, 6'b100000);
        // add $t5, $t1, $t2       ; $t5 = 13

        instructions[9] = enc_r(5'd12, 5'd13, 5'd14, 6'b100010);
        // sub $t6, $t4, $t5       ; $t6 = 4 - 13 = -9

        // Test 3: MEM/WB -> ALU input A, expected ForwardA=2'b01.
        instructions[10] = enc_r(5'd9, 5'd10, 5'd15, 6'b100000);
        // add $t7, $t1, $t2       ; $t7 = 13

        instructions[11] = enc_i(6'b001000, 5'd0, 5'd19, 16'd77);
        // addi $s3, $zero, 77     ; independent instruction

        instructions[12] = enc_r(5'd15, 5'd12, 5'd24, 6'b100010);
        // sub $t8, $t7, $t4       ; $t8 = 13 - 4 = 9

        // Test 4: MEM/WB -> ALU input B, expected ForwardB=2'b01.
        instructions[13] = enc_r(5'd9, 5'd10, 5'd25, 6'b100000);
        // add $t9, $t1, $t2       ; $t9 = 13

        instructions[14] = enc_i(6'b001000, 5'd0, 5'd20, 16'd88);
        // addi $s4, $zero, 88     ; independent instruction

        instructions[15] = enc_r(5'd12, 5'd25, 5'd21, 6'b100010);
        // sub $s5, $t4, $t9       ; $s5 = 4 - 13 = -9

        // Test 5: EX hazard must have priority over MEM hazard.
        instructions[16] = enc_r(5'd9, 5'd10, 5'd8, 6'b100000);
        // add $t0, $t1, $t2       ; older $t0 = 13

        instructions[17] = enc_r(5'd8, 5'd10, 5'd8, 6'b100000);
        // add $t0, $t0, $t2       ; newest $t0 = 16

        instructions[18] = enc_r(5'd8, 5'd12, 5'd11, 6'b100010);
        // sub $t3, $t0, $t4       ; must use 16, result = 12

        // Load memories using the same interface as the supplied testbench.
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

        // Allow the first instruction to fill the pipeline.
        #8;

        while ((commit_no < PROGRAM_LEN) && (cycle_no < MAX_CYCLES)) begin
            #2;
            cycle_no = cycle_no + 1;

            if (InstDone === 1'b1) begin
                $display(
                    "commit=%0d cycle=%0d instruction=0x%08x",
                    commit_no, cycle_no, instructions[commit_no]
                );

                // Forwarding must avoid every stall in this test.
                if ((last_commit_cycle >= 0) &&
                    ((cycle_no - last_commit_cycle) != 1)) begin
                    fail_flag = 1;
                    $display(
                        "ERROR: unexpected stall before commit %0d",
                        commit_no
                    );
                end

                case (commit_no)
                    0:  check_reg(5'd9,  32'd10);
                    1:  check_reg(5'd10, 32'd3);
                    2:  check_reg(5'd12, 32'd4);
                    3:  check_reg(5'd16, 32'd101);
                    4:  check_reg(5'd17, 32'd102);
                    5:  check_reg(5'd18, 32'd103);
                    6:  check_reg(5'd8,  32'd13);

                    7: begin
                        check_reg(5'd11, 32'd9);
                        $display("CHECK: EX/MEM forwarding to ALU input A");
                    end

                    8:  check_reg(5'd13, 32'd13);

                    9: begin
                        check_reg(5'd14, 32'hfffffff7);
                        $display("CHECK: EX/MEM forwarding to ALU input B");
                    end

                    10: check_reg(5'd15, 32'd13);
                    11: check_reg(5'd19, 32'd77);

                    12: begin
                        check_reg(5'd24, 32'd9);
                        $display("CHECK: MEM/WB forwarding to ALU input A");
                    end

                    13: check_reg(5'd25, 32'd13);
                    14: check_reg(5'd20, 32'd88);

                    15: begin
                        check_reg(5'd21, 32'hfffffff7);
                        $display("CHECK: MEM/WB forwarding to ALU input B");
                    end

                    16: check_reg(5'd8, 32'd13);
                    17: check_reg(5'd8, 32'd16);

                    18: begin
                        check_reg(5'd11, 32'd12);
                        $display("CHECK: EX/MEM priority over MEM/WB");
                    end

                    default: begin end
                endcase

                $display(
                    "    t0=%0d t3=%0d t5=%0d t6=0x%08x t7=%0d t8=%0d",
                    R[8], R[11], R[13], R[14], R[15], R[24]
                );

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
            $display("FAILED_FORWARDING_ONLY");
            $finish(1);
        end
        else begin
            $display("ACCEPTED_FORWARDING_ONLY");
            $finish(0);
        end
    end
endmodule
