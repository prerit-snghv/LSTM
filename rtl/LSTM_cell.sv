`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 28.02.2026 17:07:30
// Design Name: 
// Module Name: LSTM_cell
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
//////////////////////////////////////////////////////////////////////////////////


module LSTM_cell #(
    parameter DATA_WIDTH = 16,
    parameter ACC_WIDTH = 48,
    parameter SAT_WIDTH = 32,
    parameter FRACT_WIDTH = 12
)(
    input logic clk, rst, start,
    
    input logic signed [DATA_WIDTH-1:0] x_t,
    input logic signed [DATA_WIDTH-1:0] h_prev,
    input logic signed [DATA_WIDTH-1:0] c_prev,

    input logic signed [DATA_WIDTH-1:0] W_i,
    input logic signed [DATA_WIDTH-1:0] W_f,
    input logic signed [DATA_WIDTH-1:0] W_g,
    input logic signed [DATA_WIDTH-1:0] W_o,

    input logic signed [DATA_WIDTH-1:0] U_i,
    input logic signed [DATA_WIDTH-1:0] U_f,
    input logic signed [DATA_WIDTH-1:0] U_g,
    input logic signed [DATA_WIDTH-1:0] U_o,

    input logic signed [DATA_WIDTH-1:0] b_i,
    input logic signed [DATA_WIDTH-1:0] b_f,
    input logic signed [DATA_WIDTH-1:0] b_g,
    input logic signed [DATA_WIDTH-1:0] b_o,

    output logic done,
    output logic signed [DATA_WIDTH-1:0] h_t,
    output logic signed [DATA_WIDTH-1:0] c_t
    );

    logic proc_en;
    logic proc_clr;
    logic [1:0] src_a_sel;
    logic [1:0] src_b_sel;
    logic [1:0] gate_sel;
    logic load_pre_ac;
    logic load_i;
    logic load_f;
    logic load_g;
    logic load_o;
    logic load_c;
    logic load_h;

    LSTM_cell_cp control_path (
        .clk(clk),
        .rst(rst),
        .start(start),
        .done(done),
        .proc_en(proc_en),
        .proc_clr(proc_clr),
        .src_a_sel(src_a_sel),
        .src_b_sel(src_b_sel),
        .gate_sel(gate_sel),
        .load_pre_ac(load_pre_ac),
        .load_i(load_i),
        .load_f(load_f),
        .load_g(load_g),
        .load_o(load_o),
        .load_c(load_c),
        .load_h(load_h)
    );

    LSTM_cell_dp #(
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH),
        .SAT_WIDTH(SAT_WIDTH),
        .FRACT_WIDTH(FRACT_WIDTH)
    ) data_path (
        .clk(clk),
        .rst(rst),
        .en(1'b1), // Always enabled, control path manages the flow

        .x_t(x_t),
        .h_prev(h_prev),
        .c_prev(c_prev),

        .W_i(W_i),
        .W_f(W_f),
        .W_g(W_g),
        .W_o(W_o),

        .U_i(U_i),
        .U_f(U_f),
        .U_g(U_g),
        .U_o(U_o),

        .b_i(b_i),
        .b_f(b_f),
        .b_g(b_g),
        .b_o(b_o),

        .proc_en(proc_en),
        .proc_clr(proc_clr),
        .src_a_sel(src_a_sel),
        .src_b_sel(src_b_sel),
        .gate_sel(gate_sel),
        .load_pre_ac(load_pre_ac),
        .load_i(load_i),
        .load_f(load_f),
        .load_g(load_g),
        .load_o(load_o),
        .load_c(load_c),
        .load_h(load_h),

        .h_t(h_t),
        .c_t(c_t)
    );

endmodule
