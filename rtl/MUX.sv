`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01.03.2026 12:32:08
// Design Name: 
// Module Name: MUX
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


module MUX #(
    parameter DATA_WIDTH
)(
    input [1:0] mux_a_sel,
    input [1:0] mux_b_sel,
    input signed [DATA_WIDTH-1:0] data_in_a, // X or h vectors
    input signed [DATA_WIDTH-1:0] data_in_b, // model weights
    input signed[DATA_WIDTH-1:0] data_subbed,
    input signed [DATA_WIDTH-1:0] data_in_LUT,
    input signed [DATA_WIDTH-1:0] data_mac_feedback,
    output logic signed [DATA_WIDTH-1:0] operand_a,
    output logic signed [DATA_WIDTH-1:0] operand_b
    );
    
    // data side
    always_comb begin
        case(mux_a_sel)
            2'b00 : operand_a = data_in_a;
            2'b01 : operand_a = data_subbed;
            2'b10 : operand_a = data_mac_feedback;
            default : operand_a = 16'h0;
        endcase
    end
    
    // weight side
    always_comb begin
        case(mux_b_sel)
            2'b00 : operand_b = data_in_b;
            2'b01 : operand_b = 16'h100;
            2'b10 : operand_b = data_subbed;
            2'b11 : operand_b = data_in_LUT;
            default : operand_b = 16'h0;
        endcase
    end
        
endmodule
