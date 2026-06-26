`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11.03.2026 21:54:21
// Design Name: 
// Module Name: tb_Processor_top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////// //////////////////////////////////////

module tb_Processor_top;

    localparam integer DATA_WIDTH = 16;
    localparam integer FRACT_WIDTH = 12;
    localparam integer ACC_WIDTH = 48;

    logic clk, rst, en, clr;
    logic signed [DATA_WIDTH-1:0] data_in_a;
    logic signed [DATA_WIDTH-1:0] data_in_b;
    logic signed [DATA_WIDTH-1:0] final_out;

    integer pass_count;
    integer fail_count;

    Processor_top #(
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH),
        .FRACT_WIDTH(FRACT_WIDTH)
    ) dut (
        .clk      (clk),
        .rst      (rst),
        .en       (en),
        .clr      (clr),
        .data_in_a(data_in_a),
        .data_in_b(data_in_b),
        .final_out(final_out)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 100 MHz clock
    end

    task automatic apply_and_check;
        input logic test_rst;
        input logic test_clr;
        input logic test_en;
        input logic signed [DATA_WIDTH-1:0] operand_a;
        input logic signed [DATA_WIDTH-1:0] operand_b;
        input logic signed [DATA_WIDTH-1:0] expected;
        input [127:0] label;
        begin
            @(negedge clk);
            rst = test_rst;
            clr = test_clr;
            en = test_en;
            data_in_a = operand_a;
            data_in_b = operand_b;

            @(posedge clk);
            #1;

            if (final_out === expected) begin
                pass_count = pass_count + 1;
                $display("PASS %-16s output=%0d expected=%0d", label, final_out, expected);
            end
            else begin
                fail_count = fail_count + 1;
                $display("FAIL %-16s output=%0d expected=%0d", label, final_out, expected);
            end
        end
    endtask

    initial begin
        rst = 1'b0;
        clr = 1'b0;
        en = 1'b0;
        data_in_a = '0;
        data_in_b = '0;
        pass_count = 0;
        fail_count = 0;

        apply_and_check(1'b1, 1'b0, 1'b0, 16'sd0,      16'sd0,     16'sd0,      "reset");
        apply_and_check(1'b0, 1'b1, 1'b0, 16'sd4096,   16'sd2048,  16'sd2048,   "clr 1.0*0.5");
        apply_and_check(1'b0, 1'b0, 1'b1, 16'sd4096,   16'sd2048,  16'sd4096,   "acc +1.0*0.5");
        apply_and_check(1'b0, 1'b0, 1'b0, 16'sd16384,  16'sd16384, 16'sd4096,   "hold");
        apply_and_check(1'b0, 1'b0, 1'b1, -16'sd4096,  16'sd2048,  16'sd2048,   "acc -1.0*0.5");
        apply_and_check(1'b0, 1'b1, 1'b0, 16'sd32767,  16'sd32767, 16'sh7fff,   "positive sat");
        apply_and_check(1'b0, 1'b1, 1'b0, -16'sd32768, 16'sd32767, 16'sh8000,   "negative sat");

        $display("Test summary: pass=%0d fail=%0d", pass_count, fail_count);

        if (fail_count == 0) begin
            $display("tb_Processor_top completed successfully.");
        end
        else begin
            $fatal(1, "tb_Processor_top detected %0d failures.", fail_count);
        end

        #10;
        $finish;
    end

endmodule
