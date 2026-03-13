`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 28.02.2026 17:07:30
// Design Name: 
// Module Name: Processor_top
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


module Processor_top #(
    parameter DATA_WIDTH = 16,
    parameter ACC_WIDTH = 48,
    parameter FRACT_WIDTH = 8,
    parameter DEPTH = 65536
)(
    input clk, rst, en, clr, mean_we, var_we,
    input [1:0] mux_a_sel,
    input [1:0] mux_b_sel,
    input signed [DATA_WIDTH-1:0] data_in_a,
    input signed [DATA_WIDTH-1:0] data_in_b,
    input signed [DATA_WIDTH-1:0] inv_N,
    output signed [DATA_WIDTH-1:0] final_out,
    output signed [DATA_WIDTH-1:0] mean_out,
    output signed [DATA_WIDTH-1:0] var_out
    );

    logic signed [DATA_WIDTH-1:0] muxa_to_mac;
    logic signed [DATA_WIDTH-1:0] muxb_to_mac;
    logic signed [ACC_WIDTH-1:0] mac_48bits_out;
    logic signed [DATA_WIDTH-1:0] mac_16bits_out;
    logic signed [DATA_WIDTH-1:0] div_to_state;
    logic signed [DATA_WIDTH-1:0] subbed_to_mux;
    logic signed [DATA_WIDTH-1:0] lut_to_mux;

    MUX #(
        .DATA_WIDTH(DATA_WIDTH)
     ) mux (
        .mux_a_sel        (mux_a_sel),
        .mux_b_sel        (mux_b_sel),
        .data_in_a        (data_in_a),
        .data_in_b        (data_in_b),
        .data_subbed      (subbed_to_mux),
        .data_in_LUT      (lut_to_mux),
        .data_mac_feedback(mac_16bits_out),
        .operand_a        (muxa_to_mac),
        .operand_b        (muxb_to_mac)
    );

    MAC #(
        .DATA_WIDTH (DATA_WIDTH),
        .FRACT_WIDTH(FRACT_WIDTH),
        .ACC_WIDTH  (ACC_WIDTH)
     ) mac (
        .clk      (clk),
        .rst      (rst),
        .en       (en),
        .clr      (clr),
        .data_in_a(muxa_to_mac),
        .data_in_b(muxb_to_mac),
        .data_out (mac_48bits_out)
    );

    Saturation_checker #(
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH (ACC_WIDTH)
     ) saturation_checker (
        .data_in (mac_48bits_out),
        .data_out(mac_16bits_out)
    );

    assign final_out = mac_16bits_out;
    
    LayerNorm_divider #(
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH (ACC_WIDTH)
     ) layerNorm_divider (
        .data_in (mac_48bits_out),
        .inv_N   (inv_N),
        .data_out(div_to_state)
    );

    LayerNorm_glue_logic #(
        .DATA_WIDTH(DATA_WIDTH)
     ) layerNorm_glue_logic (
        .clk        (clk),
        .rst        (rst),
        .mean_we    (mean_we),
        .var_we     (var_we),
        .data_in    (data_in_a),
        .mean_in    (div_to_state),
        .var_in     (div_to_state),
        .data_subbed(subbed_to_mux),
        .mean_out   (mean_out),
        .var_out    (var_out)
    );

    LayerNorm_LUT #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH     (DEPTH)
     ) layerNorm_LUT (
        .clk     (clk),
        .data_in (var_out),
        .data_out(lut_to_mux)
    );

endmodule
