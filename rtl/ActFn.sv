`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01.04.2026 21:44:30
// Design Name: 
// Module Name: Activation Function
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

module ActFn #(
    parameter DATA_WIDTH = 16,
    parameter FRACT_WIDTH = 12
)(

    input act_fn,
    input logic signed [DATA_WIDTH-1:0] data_in,
    output logic signed [DATA_WIDTH-1:0] data_out
    
    );


    logic [DATA_WIDTH-1:0] x_abs;
    logic signed [DATA_WIDTH-1:0] poly_data;
    // Lower fractional bits are truncated by FP shift
    // Intentional for Q-format polynomial evaluation
    logic signed [DATA_WIDTH-1:0] stage1;
    logic signed [DATA_WIDTH-1:0] stage2;
    logic flag_neg;
    logic [1:0] seg;
    logic signed [DATA_WIDTH-1:0] c0;
    logic signed [DATA_WIDTH-1:0] c1;
    logic signed [DATA_WIDTH-1:0] c2;
    logic signed [DATA_WIDTH-1:0] c3;
    logic [DATA_WIDTH:0] abs_wide;
    logic [DATA_WIDTH:0] scaled_abs_wide;

    localparam signed [DATA_WIDTH-1:0] MAXPOS = 16'sh7FFF;
    localparam signed [DATA_WIDTH-1:0] MAXNEG = 16'sh8000;

    localparam signed [DATA_WIDTH-1:0] ONE = (1 <<< FRACT_WIDTH);
    localparam signed [DATA_WIDTH-1:0] THREE = (3 <<< FRACT_WIDTH);
    localparam signed [DATA_WIDTH-1:0] FIVE = (5 <<< FRACT_WIDTH);

    localparam signed [DATA_WIDTH-1:0] SIG0_C0 = 16'sd2048;
    localparam signed [DATA_WIDTH-1:0] SIG0_C1 = 16'sd1024;
    localparam signed [DATA_WIDTH-1:0] SIG0_C2 = -16'sd4;
    localparam signed [DATA_WIDTH-1:0] SIG0_C3 = -16'sd76;

    localparam signed [DATA_WIDTH-1:0] SIG1_C0 = 16'sd1967;
    localparam signed [DATA_WIDTH-1:0] SIG1_C1 = 16'sd1261;
    localparam signed [DATA_WIDTH-1:0] SIG1_C2 = -16'sd247;
    localparam signed [DATA_WIDTH-1:0] SIG1_C3 = 16'sd14;

    localparam signed [DATA_WIDTH-1:0] SIG2_C0 = 16'sd2188;
    localparam signed [DATA_WIDTH-1:0] SIG2_C1 = 16'sd1102;
    localparam signed [DATA_WIDTH-1:0] SIG2_C2 = -16'sd225;
    localparam signed [DATA_WIDTH-1:0] SIG2_C3 = 16'sd16;

    function logic signed [DATA_WIDTH-1:0] saturation_result (
        input logic [DATA_WIDTH-1:0] a,
        input logic signed [DATA_WIDTH-1:0] b
    );
        logic signed [DATA_WIDTH-1:0] sat_result;
        logic signed [2*DATA_WIDTH+2:0] result;

        result = ($signed({1'b0, a}) * $signed({b[DATA_WIDTH-1], b})) >>> FRACT_WIDTH;

        if (|result[2*DATA_WIDTH+1:DATA_WIDTH-1] && !result[2*DATA_WIDTH+2]) sat_result = MAXPOS;
        else if (~&result[2*DATA_WIDTH+1:DATA_WIDTH-1] && result[2*DATA_WIDTH+2]) sat_result = MAXNEG;
        else sat_result = $signed(result[DATA_WIDTH-1:0]);

        return sat_result;
    endfunction

    always_comb begin
        if(data_in[DATA_WIDTH-1]==1) begin
            flag_neg = 1'b1;
            abs_wide = {1'b0, (~($unsigned(data_in)) + 1'b1)};
        end
        else begin
            flag_neg = 1'b0;
            abs_wide = {1'b0, data_in};
        end

        if (act_fn) begin
            // tanh(x) = 2*sigmoid(2x) - 1, so reuse the sigmoid polynomial on 2|x|.
            scaled_abs_wide = abs_wide <<< 1;
        end
        else begin
            scaled_abs_wide = abs_wide;
        end

        // Clamp before narrowing back to DATA_WIDTH so the doubled tanh input
        // saturates cleanly instead of wrapping on overflow.
        if (scaled_abs_wide > {1'b0, {DATA_WIDTH{1'b1}}}) begin
            x_abs = {DATA_WIDTH{1'b1}};
        end
        else begin
            x_abs = scaled_abs_wide[DATA_WIDTH-1:0];
        end
    end

    always_comb begin
        if($unsigned(x_abs) < $unsigned(ONE)) begin
            seg = 2'b00;
        end
        else if($unsigned(x_abs) < $unsigned(THREE)) begin
            seg = 2'b01;
        end
        else if($unsigned(x_abs) < $unsigned(FIVE)) begin
            seg = 2'b10;
        end
        else seg = 2'b11;
    end

    always_comb begin
        case (seg)
            2'b00: begin
                c0 = SIG0_C0;
                c1 = SIG0_C1;
                c2 = SIG0_C2;
                c3 = SIG0_C3;
            end
            2'b01: begin
                c0 = SIG1_C0;
                c1 = SIG1_C1;
                c2 = SIG1_C2;
                c3 = SIG1_C3;
            end
            2'b10: begin
                c0 = SIG2_C0;
                c1 = SIG2_C1;
                c2 = SIG2_C2;
                c3 = SIG2_C3;
            end
            default: begin
                c0 = 16'sd0;
                c1 = 16'sd0;
                c2 = 16'sd0;
                c3 = 16'sd0;
            end
        endcase
    end

    always_comb begin
        if (seg == 2'b11) begin
            stage1 = 16'sd0;
            stage2 = 16'sd0;
            poly_data = ONE;
        end
        else begin
            stage1 =  saturation_result(x_abs, c3) + c2;
            stage2 =  saturation_result(x_abs, stage1) + c1;
            poly_data = saturation_result(x_abs, stage2) + c0;
        end
        if (poly_data > ONE) poly_data = ONE;
        else if (poly_data < 16'sd0) poly_data = 16'sd0;
    end

    always_comb begin
        case(flag_neg)
            // Positive tanh branch: 2*sigmoid(2x) - 1. Sigmoid mode just returns poly_data.
            1'b0: data_out = (act_fn) ?  ((poly_data <<< 1) - ONE) : poly_data ;
            // Negative tanh branch uses tanh(-x) = -tanh(x). Sigmoid mode uses 1-sigmoid(|x|).
            1'b1: data_out = (act_fn) ? (((ONE - poly_data) <<< 1) - ONE) : (ONE - poly_data);
            default: data_out = 16'sd0;
        endcase
    end

endmodule
