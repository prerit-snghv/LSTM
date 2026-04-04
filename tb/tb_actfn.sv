`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Testbench for ActFn.sv
// act_fn = 0 -> sigmoid mode
// act_fn = 1 -> tanh mode
// Assumes Q4.12 fixed-point format.
//////////////////////////////////////////////////////////////////////////////////

module tb_actfn;

    localparam integer DATA_WIDTH = 16;
    localparam real Q_SCALE = 4096.0;
    localparam integer SIG_TOLERANCE = 16;
    localparam integer TANH_TOLERANCE = 16;

    logic act_fn;
    logic signed [DATA_WIDTH-1:0] data_in;
    logic signed [DATA_WIDTH-1:0] data_out;

    integer pass_count;
    integer fail_count;
    integer diff;
    real input_real;
    real output_real;
    real expected_real;
    real diff_real;
    real tolerance_real;

    ActFn #(
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .act_fn(act_fn),
        .data_in(data_in),
        .data_out(data_out)
    );

    // Convert raw Q4.12 counts into a human-readable real number.
    function real q12_to_real;
        input integer value_q;
        begin
            q12_to_real = real'(value_q) / Q_SCALE;
        end
    endfunction

    // Shared checker used for both sigmoid and tanh mode.
    task automatic apply_and_check;
        input integer act_mode;
        input integer input_q;
        input integer expected_q;
        input integer tolerance;
        input [127:0] label;
        begin
            act_fn = act_mode[0];
            data_in = signed'(input_q[DATA_WIDTH-1:0]);
            #1;

            diff = integer'(data_out) - expected_q;
            if (diff < 0) begin
                diff = -diff;
            end

            input_real = q12_to_real(input_q);
            output_real = q12_to_real(integer'(data_out));
            expected_real = q12_to_real(expected_q);
            diff_real = q12_to_real(diff);
            tolerance_real = q12_to_real(tolerance);

            if (diff <= tolerance) begin
                pass_count = pass_count + 1;
                $display("PASS mode=%0d %-12s input=%0d (%.6f) output=%0d (%.6f) expected=%0d (%.6f) diff=%0d (%.6f) tol=%0d (%.6f)",
                         act_mode, label, input_q, input_real, integer'(data_out), output_real,
                         expected_q, expected_real, diff, diff_real, tolerance, tolerance_real);
            end
            else begin
                fail_count = fail_count + 1;
                $display("FAIL mode=%0d %-12s input=%0d (%.6f) output=%0d (%.6f) expected=%0d (%.6f) diff=%0d (%.6f) tol=%0d (%.6f)",
                         act_mode, label, input_q, input_real, integer'(data_out), output_real,
                         expected_q, expected_real, diff, diff_real, tolerance, tolerance_real);
            end
        end
    endtask

    initial begin
        act_fn = 1'b0;
        data_in = '0;
        pass_count = 0;
        fail_count = 0;
        diff = 0;

        // Print the fixed-point scale and tolerances once at the start so the
        // later PASS/FAIL lines are easier to interpret.
        $display("Q4.12 scale = %.1f counts per 1.0", Q_SCALE);
        $display("Sigmoid tolerance = %0d counts = %.6f", SIG_TOLERANCE, q12_to_real(SIG_TOLERANCE));
        $display("Tanh tolerance    = %0d counts = %.6f", TANH_TOLERANCE, q12_to_real(TANH_TOLERANCE));

        $display("Checking sigmoid mode");
        apply_and_check(0, -8192,   488,  SIG_TOLERANCE, "x=-2.0");
        apply_and_check(0, -4096,  1101,  SIG_TOLERANCE, "x=-1.0");
        apply_and_check(0, -2048,  1548,  SIG_TOLERANCE, "x=-0.5");
        apply_and_check(0, -1024,  1795,  SIG_TOLERANCE, "x=-0.25");
        apply_and_check(0, 0,      2048,  SIG_TOLERANCE, "x=0");
        apply_and_check(0, 1024,   2301,  SIG_TOLERANCE, "x=0.25");
        apply_and_check(0, 2048,   2548,  SIG_TOLERANCE, "x=0.5");
        apply_and_check(0, 4096,   2995,  SIG_TOLERANCE, "x=1.0");
        apply_and_check(0, 8192,   3608,  SIG_TOLERANCE, "x=2.0");

        $display("Checking tanh mode");
        apply_and_check(1, -4096, -3119, TANH_TOLERANCE, "x=-1.0");
        apply_and_check(1, -2048, -1894, TANH_TOLERANCE, "x=-0.5");
        apply_and_check(1, -1024, -1002, TANH_TOLERANCE, "x=-0.25");
        apply_and_check(1, 0,         0, TANH_TOLERANCE, "x=0");
        apply_and_check(1, 1024,   1002, TANH_TOLERANCE, "x=0.25");
        apply_and_check(1, 2048,   1894, TANH_TOLERANCE, "x=0.5");
        apply_and_check(1, 4096,   3119, TANH_TOLERANCE, "x=1.0");

        // Each line above prints both the raw fixed-point value and its real
        // interpretation, so the summary can stay compact.
        $display("Test summary: pass=%0d fail=%0d", pass_count, fail_count);

        if (fail_count == 0) begin
            $display("tb_actfn completed successfully.");
        end
        else begin
            $fatal(1, "tb_actfn detected %0d failures.", fail_count);
        end

        #10;
        $finish;
    end

endmodule
