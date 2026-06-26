`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 24.06.2026 23:55:30
// Design Name: 
// Module Name: LSTM_cell_cp
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

module LSTM_cell_cp (
    input logic clk, 
    input logic rst, 
    input logic start,
    output logic done,

    output logic proc_en,
    output  logic proc_clr,
    output  logic [1:0] src_a_sel,
    output  logic [1:0] src_b_sel,
    output  logic [1:0] gate_sel,
    output  logic load_pre_ac,
    output  logic load_i,
    output  logic load_f,
    output  logic load_g,
    output  logic load_o,
    output  logic load_c,
    output  logic load_h
);

typedef enum logic [4:0] {

    // group in 4 to use the encoding of the states for easy and clever gate selection, instead of explicit mapping

    I_WX,
    F_WX,
    G_WX,
    O_WX,

    I_UH,
    F_UH,
    G_UH,
    O_UH,

    I_B,
    F_B,
    G_B,
    O_B,
    
    I_PRE,
    F_PRE,
    G_PRE,
    O_PRE,

    I_ACT,
    F_ACT,
    G_ACT,
    O_ACT,

    LOAD_C,
    LOAD_H,

    IDLE,
    DONE
} state_t;

state_t current, next;

always_ff @(posedge clk or posedge rst) begin
    if (rst) current <= IDLE;
    else current <= next;
end

always_comb begin
    
    proc_en = 1'b0;
    proc_clr = 1'b0;
    src_a_sel = 2'b00;
    src_b_sel = 2'b00;
    gate_sel = 2'b00;
    load_pre_ac = 1'b0;
    load_i = 1'b0;
    load_f = 1'b0;
    load_g = 1'b0;
    load_o = 1'b0;
    load_c = 1'b0;
    load_h = 1'b0;
    done = 1'b0;
    
    case (current)
        
        IDLE: ;
        
        I_WX, F_WX, G_WX, O_WX: begin
            proc_clr = 1'b1;
            src_a_sel = 2'b00; // W
            src_b_sel = 2'b00; // x_t
            gate_sel = current[1:0];
        end
        
        I_UH, F_UH, G_UH, O_UH: begin
            proc_en = 1'b1;
            src_a_sel = 2'b01; // U
            src_b_sel = 2'b01; // h_t-1
            gate_sel = current[1:0];
        end
        
        I_B, F_B, G_B, O_B: begin
            proc_en = 1'b1;
            src_a_sel = 2'b10; // B
            src_b_sel = 2'b11; // 1
            gate_sel = current[1:0];
        end
        
        I_PRE, F_PRE, G_PRE, O_PRE: begin
            load_pre_ac = 1'b1;
            gate_sel = current[1:0];
        end
        
        I_ACT: begin
            load_i = 1'b1;
            gate_sel = current[1:0];
        end
        
        F_ACT: begin
            load_f = 1'b1;
            gate_sel = current[1:0];
        end
        
        G_ACT: begin
            load_g = 1'b1;
            gate_sel = current[1:0];
        end

        O_ACT: begin
            load_o = 1'b1;
            gate_sel = current[1:0];
        end

        LOAD_C: load_c = 1'b1;
        
        LOAD_H: load_h = 1'b1;
        
        DONE: done = 1'b1;

        default: ;

    endcase

    next = current;
    case (current)
        IDLE:       next = start ? I_WX : IDLE;
        I_WX:       next = I_UH;
        I_UH:       next = I_B;
        I_B:        next = I_PRE;
        I_PRE:      next = I_ACT;
        I_ACT:      next = F_WX;
        F_WX:       next = F_UH;
        F_UH:       next = F_B;
        F_B:        next = F_PRE;
        F_PRE:      next = F_ACT;
        F_ACT:      next = G_WX;
        G_WX:       next = G_UH;
        G_UH:       next = G_B;
        G_B:        next = G_PRE;
        G_PRE:      next = G_ACT;
        G_ACT:      next = O_WX;
        O_WX:       next = O_UH;
        O_UH:       next = O_B;
        O_B:        next = O_PRE;
        O_PRE:      next = O_ACT;
        O_ACT:      next = LOAD_C;
        LOAD_C:     next = LOAD_H;
        LOAD_H:     next = DONE;
        DONE:       next = start ? DONE : IDLE;
        default:    next = IDLE;
    endcase

end 

endmodule