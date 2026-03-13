`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08.03.2026 13:07:30
// Design Name: 
// Module Name: LayerNorm_LUT
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


module LayerNorm_LUT #(
    parameter DATA_WIDTH, DEPTH                     // memory depth
)(
    input clk,
    input signed [DATA_WIDTH-1:0] data_in,          // variance
    output logic signed [DATA_WIDTH-1:0] data_out   // inverse of square root
    );

    logic signed [DATA_WIDTH-1:0] rom_memory [0:DEPTH-1];

    initial begin
        $readmemh("inv_sqrt.mem", rom_memory);
    end

    always_ff @(posedge clk) begin
        data_out <= rom_memory[data_in];
    end

endmodule