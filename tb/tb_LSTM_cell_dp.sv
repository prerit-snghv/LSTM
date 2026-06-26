`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Testbench for LSTM_cell_dp.sv
//////////////////////////////////////////////////////////////////////////////////

module tb_LSTM_cell_dp;

    localparam integer DATA_WIDTH = 16;
    localparam integer ACC_WIDTH = 48;
    localparam integer SAT_WIDTH = 32;
    localparam integer FRACT_WIDTH = 12;

    logic clk, rst, en;
    
    logic signed [DATA_WIDTH-1:0] x_t;
    logic signed [DATA_WIDTH-1:0] h_prev;
    logic signed [DATA_WIDTH-1:0] c_prev;

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

    logic proc_en;
    logic proc_clr;
    logic [1:0] src_a_sel;
    logic [1:0] src_b_sel;
    logic [1:0] gate_sel;
    logic load_pre_ac;
    logic load_i;
    logic load_f;
    logic load_g;
    logic load_o;
    logic load_c;
    logic load_h;

    logic signed [DATA_WIDTH-1:0] h_t;
    logic signed [DATA_WIDTH-1:0] c_t;

    LSTM_cell_dp #(
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH),
        .SAT_WIDTH(SAT_WIDTH),
        .FRACT_WIDTH(FRACT_WIDTH)
    ) dut (
        .clk(clk),
        .rst(rst),
        .en(en),
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
        .proc_en(proc_en),
        .proc_clr(proc_clr),
        .src_a_sel(src_a_sel),
        .src_b_sel(src_b_sel),
        .gate_sel(gate_sel),
        .load_pre_ac(load_pre_ac),
        .load_i(load_i),
        .load_f(load_f),
        .load_g(load_g),
        .load_o(load_o),
        .load_c(load_c),
        .load_h(load_h),
        .h_t(h_t),
        .c_t(c_t)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    task automatic reset_dut;
        begin
            rst = 1;
            en = 0;

            proc_en = 0;
            proc_clr = 0;
            src_a_sel = 0;
            src_b_sel = 0;
            gate_sel = 0;

            load_pre_ac = 0;
            load_i = 0;
            load_f = 0;
            load_g = 0;
            load_o = 0;
            load_c = 0;
            load_h = 0;
            
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
            en = 1;
            @(posedge clk);
        end
    endtask

    task automatic clear_controls;
        begin
            proc_en = 0;
            proc_clr = 0;
            load_pre_ac = 0;
            load_i = 0;
            load_f = 0;
            load_g = 0;
            load_o = 0;
            load_c = 0;
            load_h = 0;
        end
    endtask

    task automatic mac_step;
        input logic clr;
        input logic [1:0] a_sel;
        input logic [1:0] b_sel;
        begin
            clear_controls();

            proc_clr = clr;
            proc_en = !clr;
            src_a_sel = a_sel;
            src_b_sel = b_sel;

            @(posedge clk);
            #1;

            clear_controls();
        end
    endtask

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

    task automatic compute_gate;
        input logic [1:0] gate;
        input integer pre_act_exp;
        input integer act_exp;
        begin

            gate_sel = gate;

            // W_gate * x_t
            mac_step(1'b1,2'b00,2'b00);

            // + U_gate * h_prev
            mac_step(1'b0,2'b01,2'b01);

            // + b_gate * ONE
            mac_step(1'b0, 2'b10,2'b11);

            // Capture preactivation
            clear_controls();
            load_pre_ac = 1;
            @(posedge clk);
            #1;
            clear_controls();
            expect_q12($sformatf("pre_act_%b", gate), dut.preact_reg, pre_act_exp);
            
            // Capture activation into selected gate register
            case(gate)
                2'b00: load_i = 1;
                2'b01: load_f = 1;
                2'b10: load_g = 1;
                2'b11: load_o = 1;
                default: $fatal(1, "Invalid gate selection");
            endcase

            @(posedge clk);
            #1;
            clear_controls();

            case(gate)
                2'b00: expect_q12("i_reg", dut.i_reg, act_exp);
                2'b01: expect_q12("f_reg", dut.f_reg, act_exp);
                2'b10: expect_q12("g_reg", dut.g_reg, act_exp);
                2'b11: expect_q12("o_reg", dut.o_reg, act_exp);
                default: $fatal(1, "Invalid gate selection");
            endcase
        end
    endtask

    task automatic run_case;
        input string case_name;

        input logic signed [DATA_WIDTH-1:0] x_in, h_in, c_in;

        input logic signed [DATA_WIDTH-1:0] Wi, Ui, bi;
        input logic signed [DATA_WIDTH-1:0] Wf, Uf, bf;
        input logic signed [DATA_WIDTH-1:0] Wg, Ug, bg;
        input logic signed [DATA_WIDTH-1:0] Wo, Uo, bo;

        input integer exp_pre_i;
        input integer exp_pre_f;
        input integer exp_pre_g;
        input integer exp_pre_o;

        input integer exp_i;
        input integer exp_f;
        input integer exp_g;
        input integer exp_o;

        input integer exp_c;
        input integer exp_h;
        
        begin
            
            $display("Running %s", case_name);

            reset_dut();

            x_t = x_in;
            h_prev = h_in;
            c_prev = c_in;

            W_i = Wi; U_i = Ui; b_i = bi;
            W_f = Wf; U_f = Uf; b_f = bf;
            W_g = Wg; U_g = Ug; b_g = bg;
            W_o = Wo; U_o = Uo; b_o = bo;

            compute_gate(2'b00, exp_pre_i, exp_i);
            compute_gate(2'b01, exp_pre_f, exp_f);
            compute_gate(2'b10, exp_pre_g, exp_g);
            compute_gate(2'b11, exp_pre_o, exp_o);

            // compute c_t            
            clear_controls();
            load_c = 1;
            @(posedge clk);
            #1;
            clear_controls();

            if ($isunknown(c_t)) $fatal(1, "c_t is X");
            expect_q12("c_reg",dut.c_t, exp_c);

            // Compute h_t            
            clear_controls();
            load_h = 1;
            @(posedge clk);
            #1;
            clear_controls();

            if ($isunknown(h_t)) $fatal(1, "h_t is X");
            expect_q12("h_reg",dut.h_t, exp_h);

            $display("c_t = %0d", c_t);
            $display("h_t = %0d", h_t);

            #20;
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

    initial begin

        run_case(
            "Nominal_positive",
            real_to_q12(1.0), real_to_q12(0.5), real_to_q12(0.25),
            real_to_q12(1.0), real_to_q12(0.0), real_to_q12(0.0),
            real_to_q12(1.0), real_to_q12(0.0), real_to_q12(0.0),
            real_to_q12(0.5), real_to_q12(0.0), real_to_q12(0.0),
            real_to_q12(1.0), real_to_q12(0.0), real_to_q12(0.0),
            q12(4096), q12(4096), q12(2048), q12(4096),
            q12(2995), q12(2995), q12(1894), q12(2995),
            q12(2132), q12(1430)
        );

        run_case(
            "Nominal_negative",
            real_to_q12(-1.0), real_to_q12(-0.5), real_to_q12(-0.25),
            real_to_q12(-1.0), real_to_q12(0.0), real_to_q12(0.0),
            real_to_q12(-1.0), real_to_q12(0.0), real_to_q12(0.0),
            real_to_q12(-0.5), real_to_q12(0.0), real_to_q12(0.0),
            real_to_q12(-1.0), real_to_q12(0.0), real_to_q12(0.0),
            q12(4096), q12(4096), q12(2048), q12(4096),
            q12(2995), q12(2995), q12(1894), q12(2995),
            q12(635), q12(459)
        );
        
        run_case(
            "Nonzero_u",
            real_to_q12(1.0), real_to_q12(0.5), real_to_q12(0.25),
            real_to_q12(0.5), real_to_q12(0.5), real_to_q12(0.0),
            real_to_q12(1.0), real_to_q12(-0.5), real_to_q12(0.0),
            real_to_q12(0.5), real_to_q12(0.5), real_to_q12(0.0),
            real_to_q12(0.5), real_to_q12(0.5), real_to_q12(0.0),
            q12(3072), q12(3072), q12(3072), q12(3072),
            q12(2781), q12(2781), q12(2604), q12(2781),
            q12(2462), q12(1493)
        );

        run_case(
            "Nonzero_bias",
            real_to_q12(0.5), real_to_q12(0.25), real_to_q12(0.125),
            real_to_q12(0.5), real_to_q12(0.0), real_to_q12(0.25),
            real_to_q12(0.5), real_to_q12(0.0), real_to_q12(-0.25),
            real_to_q12(0.5), real_to_q12(0.0), real_to_q12(0.125),
            real_to_q12(0.5), real_to_q12(0.0), real_to_q12(-0.125),
            q12(2048), q12(0), q12(1536), q12(512),
            q12(2549), q12(2048), q12(1466), q12(2175),
            q12(1168), q12(603)
        );

        run_case(
            "Near_saturation",
            real_to_q12(2.0), real_to_q12(2.0), real_to_q12(1.0),
            real_to_q12(2.0), real_to_q12(2.0), real_to_q12(1.0),
            real_to_q12(2.0), real_to_q12(2.0), real_to_q12(1.0),
            real_to_q12(2.0), real_to_q12(2.0), real_to_q12(0.0),
            real_to_q12(2.0), real_to_q12(2.0), real_to_q12(1.0),
            q12(32767), q12(32767), q12(32767), q12(32767),
            q12(4096), q12(4096), q12(4096), q12(4096),
            q12(8192), q12(3944)
        );

        $finish;
    end

endmodule
