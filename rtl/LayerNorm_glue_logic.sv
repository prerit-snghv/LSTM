`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01.03.2026 17:11:06
// Design Name: 
// Module Name: LayerNorm_glue_logic
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


module LayerNorm_glue_logic #(
    parameter DATA_WIDTH
)(
    input clk,
    input rst,
    input mean_we,
    input var_we,
    input signed [DATA_WIDTH-1:0] data_in,
    input signed [DATA_WIDTH-1:0] mean_in,
    input signed [DATA_WIDTH-1:0] var_in,
    output signed [DATA_WIDTH-1:0] data_subbed,
    output signed [DATA_WIDTH-1:0] mean_out,
    output signed [DATA_WIDTH-1:0] var_out
    );

    logic signed [DATA_WIDTH-1:0] mean_reg;
    logic signed [DATA_WIDTH-1:0] var_reg;
    
    assign data_subbed = data_in - mean_reg;
    assign mean_out = mean_reg;
    assign var_out = var_reg;

    always_ff @(posedge clk) begin
        if(rst) begin 
            mean_reg <= 0;
            var_reg <= 0;
        end
        else begin
            if(mean_we) mean_reg <= mean_in;
            if(var_we) var_reg <= var_in;
        end
    end

endmodule