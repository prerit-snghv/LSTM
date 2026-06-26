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
    parameter DATA_WIDTH,
    parameter ACC_WIDTH,
    parameter FRACT_WIDTH
)(
    input clk, rst, en, clr,
    input signed [DATA_WIDTH-1:0] data_in_a,
    input signed [DATA_WIDTH-1:0] data_in_b,
    output signed [DATA_WIDTH-1:0] final_out
    );

    logic signed [ACC_WIDTH-1:0] mac_48bits_out;
    logic signed [DATA_WIDTH-1:0] mac_16bits_out;

    MAC #(
        .DATA_WIDTH (DATA_WIDTH),
        .FRACT_WIDTH(FRACT_WIDTH),
        .ACC_WIDTH  (ACC_WIDTH)
     ) mac (
        .clk      (clk),
        .rst      (rst),
        .en       (en),
        .clr      (clr),
        .data_in_a(data_in_a),
        .data_in_b(data_in_b),
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
    
endmodule
