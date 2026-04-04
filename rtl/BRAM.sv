`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 16.03.2026 22:21:30
// Design Name: 
// Module Name: BRAM
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


module BRAM(
    input clk, w_en, rd_en,
    input [10:0] addr_rd,
    input [10:0] addr_wr,
    input [15:0] data_in, 
    output logic [15:0] data_out
    );

    (* ram_style = "block" *) reg [15:0] mem [0:2047];

    always@(posedge clk) begin
        if(w_en) mem[addr_wr] <= data_in;
        if(rd_en) data_out <= mem[addr_rd];
    end



endmodule
