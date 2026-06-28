`timescale 1ns/1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 26.06.2026 19:13:30
// Design Name: 
// Module Name: LSTM_seq_ctrl
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description:
//   Sequences one scalar LSTM_cell across a parameterized scalar input sequence.
//
//   Start/done protocol:
//   - start is a level-sensitive request sampled in IDLE.
//   - one complete sequence is executed per start assertion.
//   - done asserts when h_final/c_final are valid.
//   - done remains high in WAIT_START_LOW until start is deasserted.
//   - a new sequence can begin only after start returns low and the FSM re-enters IDLE.
//
//   Sequence interface:
//   - x_seq[NUM_STEPS] supplies one scalar input per timestep.
//   - h_t/c_t from each completed cell evaluation are fed back as h_prev/c_prev
//     for the next timestep.
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module LSTM_seq_ctrl #(
    parameter DATA_WIDTH = 16,
    parameter ACC_WIDTH = 48,
    parameter SAT_WIDTH = 32,
    parameter FRACT_WIDTH = 12,
    parameter NUM_STEPS = 2
)(
    input logic clk, rst, start,
    input logic signed [DATA_WIDTH-1:0] x_seq[NUM_STEPS],
    input logic signed [DATA_WIDTH-1:0] h_init,
    input logic signed [DATA_WIDTH-1:0] c_init,
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
    output logic done,
    output logic signed [DATA_WIDTH-1:0] h_final,
    output logic signed [DATA_WIDTH-1:0] c_final
);

    logic cell_start;
    logic cell_done;
    logic signed [DATA_WIDTH-1:0] cell_h_t;
    logic signed [DATA_WIDTH-1:0] cell_c_t;
    logic signed [DATA_WIDTH-1:0] h_state;
    logic signed [DATA_WIDTH-1:0] c_state;
    logic [31:0] step_count;
    logic signed [DATA_WIDTH-1:0] x_selected;

    typedef enum logic [2:0] {
        IDLE,
        START_CELL,
        WAIT_CELL,
        SAVE_STATE,
        RELEASE_CELL,
        DONE,
        WAIT_START_LOW
    } state_t;

    state_t current, next;

    assign x_selected = x_seq[step_count];
    
    LSTM_cell #(
        .DATA_WIDTH (DATA_WIDTH),
        .ACC_WIDTH  (ACC_WIDTH),
        .SAT_WIDTH  (SAT_WIDTH),
        .FRACT_WIDTH(FRACT_WIDTH)
     ) lstM_cell (
        .clk   (clk),
        .rst   (rst),
        .start (cell_start),
        .x_t   (x_selected),
        .h_prev(h_state),
        .c_prev(c_state),
        .W_i   (W_i),
        .W_f   (W_f),
        .W_g   (W_g),
        .W_o   (W_o),
        .U_i   (U_i),
        .U_f   (U_f),
        .U_g   (U_g),
        .U_o   (U_o),
        .b_i   (b_i),
        .b_f   (b_f),
        .b_g   (b_g),
        .b_o   (b_o),
        .done  (cell_done),
        .h_t   (cell_h_t),
        .c_t   (cell_c_t)
    );

    always_ff @(posedge clk or posedge rst) begin
        if (rst) current <= IDLE;
        else current <= next;
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            h_state <= 0;
            c_state <= 0;
            step_count <= 0;
        end
        else begin
            if(current == IDLE && start) begin
                h_state <= h_init;
                c_state <= c_init;
                step_count <= 0;
            end
            else if(current == SAVE_STATE) begin
                h_state <= cell_h_t;
                c_state <= cell_c_t;
            end
            else if(current == RELEASE_CELL) begin
                step_count <= ((step_count != NUM_STEPS - 1) && (!cell_done)) ? step_count + 1 : step_count;
            end
        end
    end

    always_comb begin
        next = current;
        cell_start = 1'b0;
        done = 1'b0;
        h_final = h_state;
        c_final = c_state;

        case (current)
            IDLE: begin
                if (start) next = START_CELL;
                else next = IDLE;
            end

            START_CELL: begin
                cell_start = 1'b1;
                next = WAIT_CELL;
            end

            WAIT_CELL: begin
                cell_start = 1'b1;
                if (cell_done) next = SAVE_STATE;
                else next = WAIT_CELL;
            end

            SAVE_STATE: next = RELEASE_CELL;
            
            RELEASE_CELL: begin
                cell_start = 1'b0;
                if (cell_done) next = RELEASE_CELL;
                else if (step_count == NUM_STEPS - 1) next = DONE;
                else next = START_CELL;
            end

            DONE: begin
                done = 1'b1;
                next = WAIT_START_LOW;
            end

            WAIT_START_LOW: begin
                done = 1'b1;
                if (!start) next = IDLE;
                else next = WAIT_START_LOW;
            end

            default: next = IDLE;

        endcase
    end



endmodule
