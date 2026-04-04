`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 28.02.2026 17:07:30
// Design Name: 
// Module Name: LSTM_cell
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


module LSTM_cell_dp #(
    parameter DATA_WIDTH = 16,
    parameter ACC_WIDTH = 48,
    parameter FRACT_WIDTH = 12
)(
    input logic clk, rst, en,
    
    input logic signed [DATA_WIDTH-1:0] x_t,
    input logic signed [DATA_WIDTH-1:0] h_prev,
    input logic signed [DATA_WIDTH-1:0] c_prev,

    input logic signed [DATA_WIDTH-1:0] W_i,
    input logic signed [DATA_WIDTH-1:0] W_f,
    input logic signed [DATA_WIDTH-1:0] W_g,
    input logic signed [DATA_WIDTH-1:0] W_o,

    input logic signed [DATA_WIDTH-1:0] U_i,
    input logic signed [DATA_WIDTH-1:0] U_f,
    input logic signed [DATA_WIDTH-1:0] U_g,
    input logic signed [DATA_WIDTH-1:0] U_o,

    input logic signed [DATA_WIDTH-1:0] b_i,
    input logic signed [DATA_WIDTH-1:0] b_f,
    input logic signed [DATA_WIDTH-1:0] b_g,
    input logic signed [DATA_WIDTH-1:0] b_o,
    
    input  logic proc_en,
    input  logic proc_clr,
    input  logic [1:0] src_a_sel,
    input  logic [1:0] src_b_sel,
    input  logic [1:0] gate_sel,
    input  logic load_pre_ac,
    input  logic load_i,
    input  logic load_f,
    input  logic load_g,
    input  logic load_o,
    input  logic load_c,
    input  logic load_h,

    output logic signed [DATA_WIDTH-1:0] h_t,
    output logic signed [DATA_WIDTH-1:0] c_t
    );

    logic signed [DATA_WIDTH-1:0] preact_wire;
    logic signed [DATA_WIDTH-1:0] act_wire;
    logic signed [DATA_WIDTH-1:0] i_reg;
    logic signed [DATA_WIDTH-1:0] f_reg;
    logic signed [DATA_WIDTH-1:0] g_reg;
    logic signed [DATA_WIDTH-1:0] o_reg;
    logic signed [DATA_WIDTH-1:0] preact_reg;
    logic signed [DATA_WIDTH-1:0] c_reg;
    logic signed [DATA_WIDTH-1:0] h_reg;
    logic act_fn;

    logic signed [DATA_WIDTH-1:0] operand_a;
    logic signed [DATA_WIDTH-1:0] operand_b;
    

    logic signed [DATA_WIDTH-1:0] W_in;
    logic signed [DATA_WIDTH-1:0] U_in;
    logic signed [DATA_WIDTH-1:0] b_in;

    always_comb begin
        case(gate_sel)
            2'b00 : begin
                W_in = W_i;
                U_in = U_i;
                b_in = b_i;
                act_fn = 1'b0;
            end
            2'b01 : begin
                W_in = W_f;
                U_in = U_f;
                b_in = b_f;
                act_fn = 1'b0;
            end
            2'b10 : begin
                W_in = W_g;
                U_in = U_g;
                b_in = b_g;
                act_fn = 1'b1;
            end
            2'b11 : begin
                W_in = W_o;
                U_in = U_o;
                b_in = b_o;
                act_fn = 1'b0;
            end
            default : begin
                W_in = 16'h0;
                U_in = 16'h0;
                b_in = 16'h0;
                act_fn = 1'b0;
            end
        endcase
    end

    always_comb begin
        case(src_a_sel)
            2'b00 : operand_a = W_in;
            2'b01 : operand_a = U_in;
            2'b10 : operand_a = b_in;
            default : operand_a = 16'h0;
        endcase
    end

    always_comb begin
        case(src_b_sel)
            2'b00 : operand_b = x_t;
            2'b01 : operand_b = h_prev;
            2'b10 : operand_b = c_prev;
            default : operand_b = 16'h0;
        endcase
    end

    Processor_top #(
        .DATA_WIDTH (DATA_WIDTH),
        .ACC_WIDTH  (ACC_WIDTH),
        .FRACT_WIDTH(FRACT_WIDTH)
     ) processor_top_1 (
        .clk      (clk),
        .rst      (rst),
        .en       (proc_en),
        .clr      (proc_clr),
        .data_in_a(operand_a),
        .data_in_b(operand_b),
        .final_out(preact_wire)
    );

    always_ff@(posedge clk or posedge rst) begin
        if(rst) preact_reg <= 0;
        else if(en && load_pre_ac) preact_reg <= preact_wire;
    end

    ActFn #(
        .DATA_WIDTH(DATA_WIDTH)
    ) actfn0 (
        .act_fn(act_fn),
        .data_in (preact_reg),
        .data_out(act_wire)
    );

    logic tanh_c_t = 1'b1;
    logic signed [DATA_WIDTH-1:0] c_reg_tanh;

    ActFn #(
        .DATA_WIDTH(DATA_WIDTH)
     ) actfn1 (
        .act_fn  (tanh_c_t),
        .data_in (c_reg),
        .data_out(c_reg_tanh)
    );

    always_ff@(posedge clk or posedge rst) begin
        if(rst) begin
            i_reg <= 0;
            f_reg <= 0;
            g_reg <= 0;
            o_reg <= 0;
        end
        else if(en && load_i && (gate_sel==2'b00)) i_reg <= act_wire;
        else if(en && load_f && (gate_sel==2'b01)) f_reg <= act_wire;
        else if(en && load_g && (gate_sel==2'b10)) g_reg <= act_wire;
        else if(en && load_o && (gate_sel==2'b11)) o_reg <= act_wire;
    end

    // For now using multipliers, later will be changed to a custom module or other flow
    always_ff@(posedge clk or posedge rst) begin
        if(rst) begin
            c_reg <= 0;
            h_reg <= 0;
        end
        else begin
            if(en && load_c) c_reg <= $signed(f_reg * c_prev) + $signed(i_reg * g_reg);
            if(en && load_h) h_reg <= $signed(o_reg * c_reg_tanh);
        end
    end

    assign c_t = c_reg;
    assign h_t = h_reg;


endmodule
