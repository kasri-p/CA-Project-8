`timescale 1ns/1ps

module tb;
    reg clk, rst, Jen;
    reg [31:0] instructions [0:511];
    reg [31:0] data_mem    [0:511];
    reg [31:0] Jin;

    wire [31:0] Jout;
    wire        InstDone;
    wire [31:0] R3, R4, R5, R6, R7, R8, R9, R10, R19;

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
        .clk(clk), .rst(rst), .Jen(Jen), .Jin(Jin),
        .Jout(Jout), .InstDone(InstDone),
        .R3(R3), .R4(R4), .R5(R5), .R6(R6), .R7(R7),
        .R8(R8), .R9(R9), .R10(R10), .R19(R19)
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

        // Prepare branch operands well before the branch reaches ID.
        instructions[0] = enc_i(6'b001000, 5'd0, 5'd8, 16'd5);
        instructions[1] = enc_i(6'b001000, 5'd0, 5'd9, 16'd5);
        instructions[2] = enc_i(6'b001000, 5'd0, 5'd10, 16'd7);
        instructions[3] = enc_i(6'b001000, 5'd0, 5'd16, 16'd101);
        instructions[4] = enc_i(6'b001000, 5'd0, 5'd17, 16'd102);

        // Taken BEQ: target = (5 + 1) + 3 = instruction 9.
        instructions[5] = enc_i(6'b000100, 5'd8, 5'd9, 16'd3);
        instructions[6] = enc_i(6'b001000, 5'd0, 5'd2, 16'd11);
        instructions[7] = enc_i(6'b001000, 5'd0, 5'd5, 16'd99);
        instructions[8] = enc_i(6'b001000, 5'd0, 5'd6, 16'd99);
        instructions[9] = enc_i(6'b001000, 5'd0, 5'd3, 16'd42);
        instructions[10] = enc_i(6'b001000, 5'd0, 5'd4, 16'd43);

        // Non-taken BEQ: 5 != 7, so both sequential instructions execute.
        instructions[11] = enc_i(6'b000100, 5'd8, 5'd10, 16'd2);
        instructions[12] = enc_i(6'b001000, 5'd0, 5'd7, 16'd55);
        instructions[13] = enc_i(6'b001000, 5'd0, 5'd19, 16'd66);

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

        while ((R19 !== 32'd66) && (cycle_no < MAX_CYCLES)) begin
            #2;
            cycle_no = cycle_no + 1;

            if (InstDone === 1'b1) begin
                $display(
                    "commit=%0d cycle=%0d t0=%0d t1=%0d t2=%0d v1=%0d a1=%0d a2=%0d",
                    commit_no, cycle_no, R8, R9, R10, R3, R5, R6
                );

                if (commit_no == 5) begin
                    branch_commit_cycle = cycle_no;
                    $display("INFO: taken BEQ committed at cycle %0d", cycle_no);
                end

                if ((R3 === 32'd42) && (target_commit_cycle < 0)) begin
                    target_commit_cycle = cycle_no;
                    $display("INFO: BEQ target committed at cycle %0d", cycle_no);
                end

                commit_no = commit_no + 1;
            end
        end

        if (R19 !== 32'd66) begin
            fail_flag = 1;
            $display("ERROR: timeout before BEQ completion marker");
        end
        if (R3 !== 32'd42 || R4 !== 32'd43) begin
            fail_flag = 1;
            $display("ERROR: taken BEQ target failed; R3=%0d R4=%0d", R3, R4);
        end
        if (R5 !== 32'd0 || R6 !== 32'd0) begin
            fail_flag = 1;
            $display("ERROR: taken BEQ committed wrong-path code; R5=%0d R6=%0d", R5, R6);
        end
        if (R7 !== 32'd55) begin
            fail_flag = 1;
            $display("ERROR: non-taken BEQ skipped sequential code; R7=%0d", R7);
        end
        if ((branch_commit_cycle < 0) || (target_commit_cycle < 0) ||
            ((target_commit_cycle - branch_commit_cycle) != 2)) begin
            fail_flag = 1;
            $display(
                "ERROR: BEQ branch-to-target distance=%0d; expected 2",
                target_commit_cycle - branch_commit_cycle
            );
        end

        if (fail_flag == 0)
            $display("ACCEPTED_BEQ_ID_NO_HAZARD");
        else
            $display("FAILED_BEQ_ID_NO_HAZARD");

        $finish;
    end
endmodule
