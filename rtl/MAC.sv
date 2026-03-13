`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 28.02.2026 17:28:45
// Design Name: 
// Module Name: MAC
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

module MAC #(
    parameter DATA_WIDTH, FRACT_WIDTH, ACC_WIDTH
)(
    // Clock and reset
    input clk,                                  // clock for starting operation
    input rst,                                  // reset signal to reset the MAC
    
    // Control signals
    input en,                                   // enable to continue running accumalate
    input clr,                                  // clear to start new dot product
    
    // Data signals
    input signed [DATA_WIDTH-1:0] data_in_a,    // data side input
    input signed [DATA_WIDTH-1:0] data_in_b,    // weight side input
    output logic signed [ACC_WIDTH-1:0] data_out  // output data, runnning total
);
    
    logic signed [2*DATA_WIDTH-1:0] product;
    logic signed [ACC_WIDTH-1:0] shifted_product;
    logic signed [2*DATA_WIDTH-1:0] shifted_32;
    logic signed [ACC_WIDTH:0] sum;
    
    assign product = data_in_a * data_in_b;
    assign shifted_32 = product >>> FRACT_WIDTH;
    assign shifted_product = shifted_32;
    assign sum = data_out + shifted_product;
    
    always@(posedge clk) begin
        if (rst) data_out <= 0;
        else if (clr) data_out <= shifted_product;
        else if (en) begin
            if ((shifted_product[ACC_WIDTH-1] == data_out[ACC_WIDTH-1]) && (shifted_product[ACC_WIDTH-1] != sum[ACC_WIDTH-1])) begin
                if (data_out[ACC_WIDTH-1] == 1'b0) data_out <= {1'b0, {(ACC_WIDTH-1){1'b1}}};
                else data_out <= $signed({1'b1, {(ACC_WIDTH-1){1'b0}}});
            end
            else data_out <= $signed(sum[2*DATA_WIDTH-1:0]);
        end
    end
    
endmodule
