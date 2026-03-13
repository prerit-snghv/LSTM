`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07.03.2026 16:04:00
// Design Name: 
// Module Name: LayerNorm_divider
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


module LayerNorm_divider #(
    parameter DATA_WIDTH, ACC_WIDTH
)(
    input signed [ACC_WIDTH-1:0] data_in,
    input signed [DATA_WIDTH-1:0] inv_N,
    output signed [DATA_WIDTH-1:0] data_out
    );

    logic signed [ACC_WIDTH + DATA_WIDTH - 1:0] full_product;

    assign full_product = data_in * inv_N;
    assign data_out = $signed(full_product[31:16]);

endmodule
