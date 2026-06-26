`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Testbench for LSTM_cell_cp.sv
//////////////////////////////////////////////////////////////////////////////////

module tb_LSTM_cell_cp;
    logic clk, rst, start;
    logic done;
    logic proc_en, proc_clr;
    logic [1:0] src_a_sel; 
    logic [1:0] src_b_sel;
    logic [1:0] gate_sel;
    logic load_pre_ac, load_i, load_f, load_g, load_o, load_c, load_h;

    LSTM_cell_cp dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .done(done),
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
        .load_h(load_h)
    );

    task automatic expect_ctrl;
        input string name;
        input logic exp_proc_en;
        input logic exp_proc_clr;
        input logic [1:0] exp_src_a_sel;
        input logic [1:0] exp_src_b_sel;
        input logic [1:0] exp_gate_sel;
        input logic exp_load_pre_ac;
        input logic exp_load_i;
        input logic exp_load_f;
        input logic exp_load_g;
        input logic exp_load_o;
        input logic exp_load_c;
        input logic exp_load_h;
        input logic exp_done;
        begin
            #1;

            if (proc_en !== exp_proc_en)
                $fatal(1, "%s proc_en mismatch: expected %0b got %0b", name, exp_proc_en, proc_en);

            if (proc_clr !== exp_proc_clr)
                $fatal(1, "%s proc_clr mismatch: expected %0b got %0b", name, exp_proc_clr, proc_clr);

            if (src_a_sel !== exp_src_a_sel)
                $fatal(1, "%s src_a_sel mismatch: expected %0b got %0b", name, exp_src_a_sel, src_a_sel);

            if (src_b_sel !== exp_src_b_sel)
                $fatal(1, "%s src_b_sel mismatch: expected %0b got %0b", name, exp_src_b_sel, src_b_sel);

            if (gate_sel !== exp_gate_sel)
                $fatal(1, "%s gate_sel mismatch: expected %0b got %0b", name, exp_gate_sel, gate_sel);

            if (load_pre_ac !== exp_load_pre_ac)
                $fatal(1, "%s load_pre_ac mismatch: expected %0b got %0b", name, exp_load_pre_ac, load_pre_ac);

            if (load_i !== exp_load_i)
                $fatal(1, "%s load_i mismatch: expected %0b got %0b", name, exp_load_i, load_i);

            if (load_f !== exp_load_f)
                $fatal(1, "%s load_f mismatch: expected %0b got %0b", name, exp_load_f, load_f);

            if (load_g !== exp_load_g)
                $fatal(1, "%s load_g mismatch: expected %0b got %0b", name, exp_load_g, load_g);

            if (load_o !== exp_load_o)
                $fatal(1, "%s load_o mismatch: expected %0b got %0b", name, exp_load_o, load_o);

            if (load_c !== exp_load_c)
                $fatal(1, "%s load_c mismatch: expected %0b got %0b", name, exp_load_c, load_c);

            if (load_h !== exp_load_h)
                $fatal(1, "%s load_h mismatch: expected %0b got %0b", name, exp_load_h, load_h);

            if (done !== exp_done)
                $fatal(1, "%s done mismatch: expected %0b got %0b", name, exp_done, done);

            $display("PASS %s", name);
        end
    endtask

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        rst = 1;
        start = 0;

        repeat (2) @(posedge clk);
        rst = 0;

        @(posedge clk);
        expect_ctrl(
            "IDLE",
            1'b0, 1'b0, 2'b00, 2'b00, 2'b00,
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0
        );

        start = 1;

        @(posedge clk);
        expect_ctrl(
            "I_WX",
            1'b0, 1'b1, 2'b00, 2'b00, 2'b00,
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0
        );

        @(posedge clk);
        expect_ctrl(
            "I_UH",
            1'b1, 1'b0, 2'b01, 2'b01, 2'b00,
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0
        );

        @(posedge clk);
        expect_ctrl(
            "I_B",
            1'b1, 1'b0, 2'b10, 2'b11, 2'b00,
            1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0
        );

        @(posedge clk);
        expect_ctrl(
            "I_PRE",
            1'b0, 1'b0, 2'b00, 2'b00, 2'b00,
            1'b1, 1'b0, 1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0
        );

        @(posedge clk);
        expect_ctrl(
            "I_ACT",
            1'b0, 1'b0, 2'b00, 2'b00, 2'b00,
            1'b0, 1'b1, 1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0
        );

        // continue F, G, O, LOAD_C, LOAD_H, DONE
        
        @(posedge clk);
        expect_ctrl(
            "F_WX",
            1'b0, 1'b1, 2'b00, 
            2'b00, 2'b01,
            1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0,
            1'b0, 1'b0, 1'b0
        );

        @(posedge clk);
        expect_ctrl(
            "F_UH",
            1'b1, 1'b0, 2'b01, 
            2'b01, 2'b01,
            1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0,
            1'b0, 1'b0, 1'b0
        );

        @(posedge clk);
        expect_ctrl(
            "F_B",
            1'b1, 1'b0, 2'b10, 
            2'b11, 2'b01,
            1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0,
            1'b0, 1'b0, 1'b0
        );

        @(posedge clk);
        expect_ctrl(
            "F_PRE",
            1'b0, 1'b0, 2'b00, 
            2'b00, 2'b01,
            1'b1, 1'b0, 1'b0, 
            1'b0, 1'b0,
            1'b0, 1'b0, 1'b0
        );

        @(posedge clk);
        expect_ctrl(
            "F_ACT",
            1'b0, 1'b0, 2'b00, 
            2'b00, 2'b01,
            1'b0, 1'b0, 1'b1, 
            1'b0, 1'b0,
            1'b0, 1'b0, 1'b0
        );

        @(posedge clk);
        expect_ctrl(
            "G_WX",
            1'b0, 1'b1, 2'b00, 
            2'b00, 2'b10,
            1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0,
            1'b0, 1'b0, 1'b0
        );

        @(posedge clk);
        expect_ctrl(
            "G_UH",
            1'b1, 1'b0, 2'b01, 
            2'b01, 2'b10,
            1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0,
            1'b0, 1'b0, 1'b0
        );

        @(posedge clk);
        expect_ctrl(
            "G_B",
            1'b1, 1'b0, 2'b10, 
            2'b11, 2'b10,
            1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0,
            1'b0, 1'b0, 1'b0
        );

        @(posedge clk);
        expect_ctrl(
            "G_PRE",
            1'b0, 1'b0, 2'b00, 
            2'b00, 2'b10,
            1'b1, 1'b0, 1'b0, 
            1'b0, 1'b0,
            1'b0, 1'b0, 1'b0
        );

        @(posedge clk);
        expect_ctrl(
            "G_ACT",
            1'b0, 1'b0, 2'b00,
            2'b00, 2'b10,
            1'b0, 1'b0, 1'b0, 
            1'b1, 1'b0,
            1'b0, 1'b0, 1'b0
        );

        @(posedge clk);
        expect_ctrl(
            "O_WX",
            1'b0, 1'b1, 2'b00, 
            2'b00, 2'b11,
            1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0,
            1'b0, 1'b0, 1'b0
        );

        @(posedge clk);
        expect_ctrl(
            "O_UH",
            1'b1, 1'b0, 2'b01, 
            2'b01, 2'b11,
            1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0,
            1'b0, 1'b0, 1'b0
        );

        @(posedge clk);
        expect_ctrl(
            "O_B",
            1'b1, 1'b0, 2'b10, 
            2'b11, 2'b11,
            1'b0, 1'b0, 1'b0, 
            1'b0, 1'b0,
            1'b0, 1'b0, 1'b0
        );

        @(posedge clk);
        expect_ctrl(
            "O_PRE",
            1'b0, 1'b0, 2'b00, 
            2'b00, 2'b11,
            1'b1, 1'b0, 
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0
        );

        @(posedge clk);
        expect_ctrl(
            "O_ACT",
            1'b0, 1'b0, 2'b00, 
            2'b00, 2'b11,
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b1,
            1'b0, 1'b0, 1'b0
        );
        
        @(posedge clk);
        expect_ctrl(
            "LOAD_C",
            1'b0, 1'b0, 2'b00, 
            2'b00, 2'b00,
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b0,
            1'b1, 1'b0, 1'b0
        );
        
        @(posedge clk);
        expect_ctrl(
            "LOAD_H",
            1'b0, 1'b0, 2'b00, 
            2'b00, 2'b00,
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b0,
            1'b0, 1'b1, 1'b0
        );

        @(posedge clk);
        expect_ctrl(
            "DONE",
            1'b0, 1'b0, 2'b00, 
            2'b00, 2'b00,
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b0,
            1'b0, 1'b0, 1'b1
        );

        start = 0;
        @(posedge clk);
        expect_ctrl(
            "IDLE_AFTER_DONE",
            1'b0, 1'b0, 2'b00, 
            2'b00, 2'b00,
            1'b0, 1'b0, 1'b0,
            1'b0, 1'b0,
            1'b0, 1'b0, 1'b0
        );

        $finish;
    end
endmodule
