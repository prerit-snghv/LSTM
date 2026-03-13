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

    logic clk, rst, en, clr, mean_we, var_we;
    logic [1:0] mux_a_sel;
    logic [1:0] mux_b_sel;
    logic signed [15:0] data_in_a;
    logic signed [15:0] data_in_b;
    logic signed [15:0] inv_N;
    logic signed [15:0] final_out;
    logic signed [15:0] mean_out;
    logic signed [15:0] var_out;

    Processor_top dut (
        .clk      (clk),
        .rst      (rst),
        .en       (en),
        .clr      (clr),
        .mean_we  (mean_we),
        .var_we   (var_we),
        .mux_a_sel(mux_a_sel),
        .mux_b_sel(mux_b_sel),
        .data_in_a(data_in_a),
        .data_in_b(data_in_b),
        .inv_N    (inv_N),
        .final_out(final_out),
        .mean_out (mean_out),
        .var_out  (var_out)
    );

    initial begin
        
        $monitor("Time: %0t | MAC_Out: %h | Mean_We: %b | Mean_Out: %h", $time, final_out, mean_we, mean_out);
        
        rst = 1;
        clr = 1;  
        en  = 0;
        mean_we = 0;
        var_we = 0;
        mux_a_sel = 2'b00;
        mux_b_sel = 2'b00;
        data_in_a = 16'b0;
        data_in_b = 16'b0;
        inv_N = 16'b0;
        #10; 

        rst = 0;
        en = 0;
        clr = 0;
        mean_we = 0;
        var_we = 0;
        mux_a_sel = 2'b0;
        mux_b_sel = 2'b0;
        data_in_a = 16'b0;
        data_in_b = 16'b0;
        inv_N = 16'b0;
        #10;        
        
        rst = 0;
        en = 1;
        clr = 0;
        mean_we = 0;
        var_we = 0;
        mux_a_sel = 2'b00;
        mux_b_sel = 2'b01;
        data_in_a = 16'h0100;
        data_in_b = 16'b0;
        inv_N = 16'b0;
        #10;
        rst = 0;
        en = 1;
        clr = 0;
        mean_we = 0;
        var_we = 0;
        mux_a_sel = 2'b00;
        mux_b_sel = 2'b01;
        data_in_a = 16'h0200;
        data_in_b = 16'b0;
        inv_N = 16'b0;
        #10;
        rst = 0;
        en = 1;
        clr = 0;
        mean_we = 0;
        var_we = 0;
        mux_a_sel = 2'b00;
        mux_b_sel = 2'b01;
        data_in_a = 16'h0300;
        data_in_b = 16'b0;
        inv_N = 16'b0;
        #10;
        
        rst = 0;
        en = 0;
        clr = 0;
        mean_we = 1;
        var_we = 0;
        mux_a_sel = 2'b00;
        mux_b_sel = 2'b01;
        data_in_a = 16'b0;
        data_in_b = 16'b0;
        inv_N = 16'h5555;
        #10;

        if (mean_out == 16'h0200) begin
            $display("SUCCESS: Mean calculated correctly! (Got: %h)", mean_out);
        end else begin
            $display("ERROR: Mean calculation failed. Expected: 0200, Got: %h", mean_out);
        end
        
        #10;

        clr =1;
        #10;

        rst = 0;
        en = 1;
        clr = 0;
        mean_we = 0;
        var_we = 0;
        mux_a_sel = 2'b01;
        mux_b_sel = 2'b10;
        data_in_a = 16'h0100;
        #10;
        data_in_a = 16'h0200;
        #10;
        data_in_a = 16'h0300;
        #10;
        en = 0;
        var_we = 1;
        #10;
        var_we = 0;
    end


    always begin
        clk <= 0; #5;
        clk <= 1; #5;
    end


endmodule