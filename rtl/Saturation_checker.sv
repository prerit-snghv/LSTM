`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01.03.2026 16:11:21
// Design Name: 
// Module Name: Saturation_checker
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


module Saturation_checker #(
    parameter DATA_WIDTH, ACC_WIDTH
)(

    input signed [ACC_WIDTH-1:0] data_in,
    output logic signed [DATA_WIDTH-1:0] data_out
    );
    
    always_comb begin
        if(|data_in[ACC_WIDTH-2:DATA_WIDTH-1] && !data_in[ACC_WIDTH-1]) data_out = $signed(16'h7FFF);
        else if (~&data_in[ACC_WIDTH-2:DATA_WIDTH-1] && data_in[ACC_WIDTH-1]) data_out = $signed(16'h8000);
        else data_out = $signed(data_in[DATA_WIDTH-1:0]);
    end
    
endmodule
