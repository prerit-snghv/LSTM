`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Testbench for LSTM_cell.sv
//////////////////////////////////////////////////////////////////////////////////

module tb_LSTM_cell;
    localparam DATA_WIDTH = 16;
    localparam ACC_WIDTH = 48;
    localparam SAT_WIDTH = 32;
    localparam FRACT_WIDTH = 12;
    localparam MAX_CYCLES = 50;

    logic clk, rst, start;
    logic done;
    logic signed [DATA_WIDTH-1:0] x_t, h_prev, c_prev;
    logic signed [DATA_WIDTH-1:0] W_i, W_f, W_g, W_o;
    logic signed [DATA_WIDTH-1:0] U_i, U_f, U_g, U_o;
    logic signed [DATA_WIDTH-1:0] b_i, b_f, b_g, b_o;
    logic signed [DATA_WIDTH-1:0] h_t, c_t;

    LSTM_cell #(
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH),
        .SAT_WIDTH(SAT_WIDTH),
        .FRACT_WIDTH(FRACT_WIDTH)
    ) dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .done(done),
        .x_t(x_t),
        .h_prev(h_prev),
        .c_prev(c_prev),
        .W_i(W_i),
        .W_f(W_f),
        .W_g(W_g),
        .W_o(W_o),
        .U_i(U_i),
        .U_f(U_f),
        .U_g(U_g),
        .U_o(U_o),
        .b_i(b_i),
        .b_f(b_f),
        .b_g(b_g),
        .b_o(b_o),
        .h_t(h_t),
        .c_t(c_t)
    );
    
    initial clk = 0;
    always #5 clk = ~clk;
    
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
            if ($isunknown(actual)) $fatal(1, "Actual value is X");
            if (actual !== q12(expected)) $fatal(1, "%s mismatch: Expected %0d, actual %0d", name, expected, actual);
            $display("PASS %s = %0d", name, actual);
        end
    endtask


    task automatic reset_dut;
        begin
            rst = 1;
            start = 0;
            
            x_t = '0;
            h_prev = '0;
            c_prev = '0;

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

    task automatic run_case;
        input string name;
        input logic signed [DATA_WIDTH-1:0] x_in;
        input logic signed [DATA_WIDTH-1:0] h_in;
        input logic signed [DATA_WIDTH-1:0] c_in;
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
        integer cycles;

        begin
            reset_dut();

            @(posedge clk);
            x_t = x_in;
            h_prev = h_in;
            c_prev = c_in;
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

            cycles = 0;
            while (!done && cycles < MAX_CYCLES) begin
                @(posedge clk);
                cycles = cycles + 1;
            end

            if (!done) begin
                $fatal(1, "Timeout: LSTM_cell did not assert done within %0d cycles", MAX_CYCLES);
            end

            if ($isunknown(c_t)) $fatal(1, "c_t is X");
            expect_q12("c_reg",c_t, exp_c);

            if ($isunknown(h_t)) $fatal(1, "h_t is X");
            expect_q12("h_reg",h_t, exp_h);

            repeat (2) begin
                @(posedge clk);
                #1;
                if (!done) $fatal(1, "Expected done to stay high while start is high");
            end

            start = 0;
            @(posedge clk);
            #1;
            if (done) $fatal(1, "Expected done to go low after returning to IDLE");
            repeat (2) @(posedge clk);
            $display("Test case %s completed successfully.", name);
        end
    endtask

    initial begin

        run_case(
            "Nominal_positive",
            real_to_q12(1.0), real_to_q12(0.5), real_to_q12(0.25),
            real_to_q12(1.0), real_to_q12(0.0), real_to_q12(0.0),
            real_to_q12(1.0), real_to_q12(0.0), real_to_q12(0.0),
            real_to_q12(0.5), real_to_q12(0.0), real_to_q12(0.0),
            real_to_q12(1.0), real_to_q12(0.0), real_to_q12(0.0),
            q12(2132), q12(1430)
        );
        
        run_case(
            "Nominal_negative",
            real_to_q12(-1.0), real_to_q12(-0.5), real_to_q12(-0.25),
            real_to_q12(-1.0), real_to_q12(0.0), real_to_q12(0.0),
            real_to_q12(-1.0), real_to_q12(0.0), real_to_q12(0.0),
            real_to_q12(-0.5), real_to_q12(0.0), real_to_q12(0.0),
            real_to_q12(-1.0), real_to_q12(0.0), real_to_q12(0.0),
            q12(635), q12(459)
        );
        
        run_case(
            "Nonzero_u",
            real_to_q12(1.0), real_to_q12(0.5), real_to_q12(0.25),
            real_to_q12(0.5), real_to_q12(0.5), real_to_q12(0.0),
            real_to_q12(1.0), real_to_q12(-0.5), real_to_q12(0.0),
            real_to_q12(0.5), real_to_q12(0.5), real_to_q12(0.0),
            real_to_q12(0.5), real_to_q12(0.5), real_to_q12(0.0),
            q12(2462), q12(1493)
        );

        run_case(
            "Nonzero_bias",
            real_to_q12(0.5), real_to_q12(0.25), real_to_q12(0.125),
            real_to_q12(0.5), real_to_q12(0.0), real_to_q12(0.25),
            real_to_q12(0.5), real_to_q12(0.0), real_to_q12(-0.25),
            real_to_q12(0.5), real_to_q12(0.0), real_to_q12(0.125),
            real_to_q12(0.5), real_to_q12(0.0), real_to_q12(-0.125),
            q12(1168), q12(603)
        );

        run_case(
            "Near_saturation",
            real_to_q12(2.0), real_to_q12(2.0), real_to_q12(1.0),
            real_to_q12(2.0), real_to_q12(2.0), real_to_q12(1.0),
            real_to_q12(2.0), real_to_q12(2.0), real_to_q12(1.0),
            real_to_q12(2.0), real_to_q12(2.0), real_to_q12(0.0),
            real_to_q12(2.0), real_to_q12(2.0), real_to_q12(1.0),
            q12(8192), q12(3944)
        );


        $display("Testbench completed successfully.");
        $finish;
    
    end

endmodule
