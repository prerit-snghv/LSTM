`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Testbench for LSTM_seq_ctrl.sv
//
// Coverage intent:
// - validates parameterized sequence input via x_seq[NUM_STEPS]
// - runs the same regression at NUM_STEPS = 2, 3, and 4
// - checks h/c feedback across timesteps
// - covers different later-step selection, recurrent U terms, biases, sign changes, and saturation
// - verifies the level-sensitive start protocol: one sequence per start assertion,
//   with the controller parked in WAIT_START_LOW until start is released
//////////////////////////////////////////////////////////////////////////////////

module tb_LSTM_seq_ctrl;

    logic done_2_steps;
    logic done_3_steps;
    logic done_4_steps;

    tb_LSTM_seq_ctrl_steps #(.NUM_STEPS(2)) tb_steps_2 (.all_done(done_2_steps));
    tb_LSTM_seq_ctrl_steps #(.NUM_STEPS(3)) tb_steps_3 (.all_done(done_3_steps));
    tb_LSTM_seq_ctrl_steps #(.NUM_STEPS(4)) tb_steps_4 (.all_done(done_4_steps));

    initial begin
        wait (done_2_steps && done_3_steps && done_4_steps);
        #20;
        $finish;
    end

endmodule

module tb_LSTM_seq_ctrl_steps #(
    parameter int NUM_STEPS = 3
)(
    output logic all_done
);

    localparam DATA_WIDTH = 16;
    localparam ACC_WIDTH = 48;
    localparam SAT_WIDTH = 32;
    localparam FRACT_WIDTH = 12;
    localparam MAX_CYCLES = 80 * NUM_STEPS;


    logic clk, rst, start;
    logic signed [DATA_WIDTH-1:0] x_seq [NUM_STEPS];
    logic signed [DATA_WIDTH-1:0] x_case [NUM_STEPS];
    logic signed [DATA_WIDTH-1:0] h_init;
    logic signed [DATA_WIDTH-1:0] c_init;

    logic signed [DATA_WIDTH-1:0] W_i;
    logic signed [DATA_WIDTH-1:0] W_f;
    logic signed [DATA_WIDTH-1:0] W_g;
    logic signed [DATA_WIDTH-1:0] W_o;
    logic signed [DATA_WIDTH-1:0] U_i;
    logic signed [DATA_WIDTH-1:0] U_f;
    logic signed [DATA_WIDTH-1:0] U_g;
    logic signed [DATA_WIDTH-1:0] U_o;
    logic signed [DATA_WIDTH-1:0] b_i;
    logic signed [DATA_WIDTH-1:0] b_f;
    logic signed [DATA_WIDTH-1:0] b_g;
    logic signed [DATA_WIDTH-1:0] b_o;
    logic done;
    logic signed [DATA_WIDTH-1:0] h_final;
    logic signed [DATA_WIDTH-1:0] c_final;

    task automatic reset_dut;
        begin
            rst = 1;
            start = 0;
            
            foreach (x_seq[step]) x_seq[step] = '0;
            h_init = '0;
            c_init = '0;

            W_i = '0;
            W_f = '0;
            W_g = '0;
            W_o = '0;

            U_i = '0;
            U_f = '0;
            U_g = '0;
            U_o = '0;

            b_i = '0;
            b_f = '0;
            b_g = '0;
            b_o = '0;

            repeat (2) @(posedge clk);  
            rst = 0;
            @(posedge clk);
        end
    endtask

    function automatic logic signed [DATA_WIDTH-1:0] real_to_q12;
        input real value;
        integer scaled;
        begin
            if (value >= 0) begin
                scaled = $rtoi(value * (1 << FRACT_WIDTH) + 0.5);
            end else begin
                scaled = $rtoi(value * (1 << FRACT_WIDTH) - 0.5);
            end
            real_to_q12 = $signed(scaled[DATA_WIDTH-1:0]);
        end
    endfunction

    function logic signed [DATA_WIDTH-1:0] q12;
        input integer value;
        begin
            q12 = $signed(value[DATA_WIDTH-1:0]);
        end
    endfunction


    task automatic expect_q12;
        input string name;
        input logic signed [DATA_WIDTH-1:0] actual;
        input integer expected;
        begin
            if ($isunknown(actual)) $fatal(1, "[%0d steps] %s is X", NUM_STEPS, name);
            if (actual !== q12(expected))
                $fatal(1, "[%0d steps] %s mismatch: expected %0d, actual %0d", NUM_STEPS, name, expected, actual);
            $display("PASS [%0d steps] %s = %0d", NUM_STEPS, name, actual);
        end
    endtask

    task automatic set_same_sequence;
        input real value;
        begin
            foreach (x_case[step]) x_case[step] = real_to_q12(value);
        end
    endtask

    task automatic set_nominal_diff_sequence;
        begin
            foreach (x_case[step]) begin
                case (step)
                    0: x_case[step] = real_to_q12(1.0);
                    1: x_case[step] = real_to_q12(0.5);
                    2: x_case[step] = real_to_q12(0.25);
                    default: x_case[step] = real_to_q12(0.125);
                endcase
            end
        end
    endtask

    task automatic set_recurrent_sequence;
        begin
            foreach (x_case[step]) begin
                case (step)
                    0: x_case[step] = real_to_q12(1.0);
                    1: x_case[step] = real_to_q12(0.75);
                    2: x_case[step] = real_to_q12(0.25);
                    default: x_case[step] = real_to_q12(0.125);
                endcase
            end
        end
    endtask

    task automatic set_bias_sequence;
        begin
            foreach (x_case[step]) begin
                case (step)
                    0: x_case[step] = real_to_q12(0.5);
                    1: x_case[step] = real_to_q12(-0.25);
                    2: x_case[step] = real_to_q12(0.125);
                    default: x_case[step] = real_to_q12(-0.125);
                endcase
            end
        end
    endtask

    task automatic run_case;
        input string name;
        input logic signed [DATA_WIDTH-1:0] xseq [NUM_STEPS];
        input logic signed [DATA_WIDTH-1:0] hinit;
        input logic signed [DATA_WIDTH-1:0] cinit;
        input logic signed [DATA_WIDTH-1:0] Wi;
        input logic signed [DATA_WIDTH-1:0] Ui;
        input logic signed [DATA_WIDTH-1:0] bi;
        input logic signed [DATA_WIDTH-1:0] Wf;
        input logic signed [DATA_WIDTH-1:0] Uf;
        input logic signed [DATA_WIDTH-1:0] bf;
        input logic signed [DATA_WIDTH-1:0] Wg;
        input logic signed [DATA_WIDTH-1:0] Ug;
        input logic signed [DATA_WIDTH-1:0] bg;
        input logic signed [DATA_WIDTH-1:0] Wo;
        input logic signed [DATA_WIDTH-1:0] Uo;
        input logic signed [DATA_WIDTH-1:0] bo;
        input integer exp_c;
        input integer exp_h;
        input logic start_edge_case;
        integer cycles;

        begin
            if (!((NUM_STEPS == 2) || (NUM_STEPS == 3) || (NUM_STEPS == 4))) begin
                $fatal(1, "Unsupported NUM_STEPS=%0d in tb_LSTM_seq_ctrl_steps", NUM_STEPS);
            end

            reset_dut();

            @(posedge clk);
            foreach (x_seq[step]) begin
                x_seq[step] = xseq[step];
            end
            h_init = hinit;
            c_init = cinit;
            W_i = Wi;
            W_f = Wf;
            W_g = Wg;
            W_o = Wo;
            U_i = Ui;
            U_f = Uf;
            U_g = Ug;
            U_o = Uo;
            b_i = bi;
            b_f = bf;
            b_g = bg;
            b_o = bo;
            
            @(posedge clk);
            start = 1;
            @(posedge clk);
            if(!start_edge_case) start = 0;
            
            cycles = 0;
            while (!done && cycles < MAX_CYCLES) begin
                @(posedge clk);
                cycles = cycles + 1;
            end
            if (!done) $fatal(1, "[%0d steps] Timeout: LSTM_seq_ctrl did not assert done", NUM_STEPS);
            #1;
            
            $display("RESULT [%0d steps] %s cycles=%0d c_final=%0d h_final=%0d",NUM_STEPS, name, cycles, c_final, h_final);
            
            expect_q12("c_final", c_final, exp_c);
            expect_q12("h_final", h_final, exp_h);
            
            if (lstM_seq_ctrl.step_count !== NUM_STEPS - 1) $fatal(1, "[%0d steps] Expected final step_count to be %0d, got %0d", NUM_STEPS, NUM_STEPS - 1, lstM_seq_ctrl.step_count);
            
            if (start_edge_case) begin
                repeat (3) @(posedge clk);
                #1;
                if (lstM_seq_ctrl.current != lstM_seq_ctrl.WAIT_START_LOW) $fatal(1, "[%0d steps] Expected WAIT_START_LOW while start is held high", NUM_STEPS);
                start = 0;
                @(posedge clk);
                #1;
                if(lstM_seq_ctrl.current != lstM_seq_ctrl.IDLE) $fatal(1, "[%0d steps] Expected IDLE after start went low", NUM_STEPS);
            end

            repeat(2) @(posedge clk);
            $display("Test case [%0d steps] %s completed successfully.", NUM_STEPS, name);
        end
    endtask

    LSTM_seq_ctrl #(
        .DATA_WIDTH (DATA_WIDTH),
        .ACC_WIDTH  (ACC_WIDTH),
        .SAT_WIDTH  (SAT_WIDTH),
        .FRACT_WIDTH(FRACT_WIDTH),
        .NUM_STEPS  (NUM_STEPS)
     ) lstM_seq_ctrl (
        .clk    (clk),
        .rst    (rst),
        .start  (start),
        .x_seq  (x_seq),
        .h_init (h_init),
        .c_init (c_init),
        .W_i    (W_i),
        .W_f    (W_f),
        .W_g    (W_g),
        .W_o    (W_o),
        .U_i    (U_i),
        .U_f    (U_f),
        .U_g    (U_g),
        .U_o    (U_o),
        .b_i    (b_i),
        .b_f    (b_f),
        .b_g    (b_g),
        .b_o    (b_o),
        .done   (done),
        .h_final(h_final),
        .c_final(c_final)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        all_done = 1'b0;

        set_same_sequence(1.0);
        run_case(
            "Nominal same x",
            x_case,
            real_to_q12(0.5), real_to_q12(0.25),
            real_to_q12(1.0), real_to_q12(0.0), real_to_q12(0.0),
            real_to_q12(1.0), real_to_q12(0.0), real_to_q12(0.0),
            real_to_q12(0.5), real_to_q12(0.0), real_to_q12(0.0),
            real_to_q12(1.0), real_to_q12(0.0), real_to_q12(0.0),
            (NUM_STEPS == 2) ? 2942 : (NUM_STEPS == 3) ? 3535 : 3968,
            (NUM_STEPS == 2) ? 1842 : (NUM_STEPS == 3) ? 2092 : 2243,
            0
        );

        set_nominal_diff_sequence();
        run_case(
            "Nominal diff x",
            x_case,
            real_to_q12(0.5), real_to_q12(0.25),
            real_to_q12(1.0), real_to_q12(0.0), real_to_q12(0.0),
            real_to_q12(1.0), real_to_q12(0.0), real_to_q12(0.0),
            real_to_q12(0.5), real_to_q12(0.0), real_to_q12(0.0),
            real_to_q12(1.0), real_to_q12(0.0), real_to_q12(0.0),
            (NUM_STEPS == 2) ? 1949 : (NUM_STEPS == 3) ? 1380 : 866,
            (NUM_STEPS == 2) ? 1125 : (NUM_STEPS == 3) ? 746 : 452,
            0
        );
        
        set_recurrent_sequence();
        run_case(
            "Nonzero recurrent U",
            x_case,
            real_to_q12(0.5), real_to_q12(0.25),
            real_to_q12(0.5), real_to_q12(0.5), real_to_q12(0.0),
            real_to_q12(1.0), real_to_q12(-0.5), real_to_q12(0.0),
            real_to_q12(0.5), real_to_q12(0.5), real_to_q12(0.0),
            real_to_q12(0.5), real_to_q12(0.5), real_to_q12(0.0),
            (NUM_STEPS == 2) ? 2885 : (NUM_STEPS == 3) ? 2209 : 1548,
            (NUM_STEPS == 2) ? 1577 : (NUM_STEPS == 3) ? 1165 : 812,
            0
        );

        set_bias_sequence();
        run_case(
            "Nonzero bias and mixed x",
            x_case,
            real_to_q12(0.25), real_to_q12(0.125),
            real_to_q12(0.5), real_to_q12(0.0), real_to_q12(0.25),
            real_to_q12(0.5), real_to_q12(0.0), real_to_q12(-0.25),
            real_to_q12(0.5), real_to_q12(0.0), real_to_q12(0.125),
            real_to_q12(0.5), real_to_q12(0.0), real_to_q12(-0.125),
            (NUM_STEPS == 2) ? 475 : (NUM_STEPS == 3) ? 652 : 413,
            (NUM_STEPS == 2) ? 206 : (NUM_STEPS == 3) ? 312 : 185,
            0
        );

        set_same_sequence(2.0);
        run_case(
            "Near saturation",
            x_case,
            real_to_q12(2.0), real_to_q12(1.0),
            real_to_q12(2.0), real_to_q12(2.0), real_to_q12(1.0),
            real_to_q12(2.0), real_to_q12(2.0), real_to_q12(1.0),
            real_to_q12(2.0), real_to_q12(2.0), real_to_q12(0.0),
            real_to_q12(2.0), real_to_q12(2.0), real_to_q12(1.0),
            (NUM_STEPS == 2) ? 12288 : (NUM_STEPS == 3) ? 16384 : 20480,
            4096,
            0
        );
        
        set_nominal_diff_sequence();
        run_case(
            "Nominal diff x, start edge case",
            x_case,
            real_to_q12(0.5), real_to_q12(0.25),
            real_to_q12(1.0), real_to_q12(0.0), real_to_q12(0.0),
            real_to_q12(1.0), real_to_q12(0.0), real_to_q12(0.0),
            real_to_q12(0.5), real_to_q12(0.0), real_to_q12(0.0),
            real_to_q12(1.0), real_to_q12(0.0), real_to_q12(0.0),
            (NUM_STEPS == 2) ? 1949 : (NUM_STEPS == 3) ? 1380 : 866,
            (NUM_STEPS == 2) ? 1125 : (NUM_STEPS == 3) ? 746 : 452,
            1
        );

        all_done = 1'b1;
    end

endmodule
