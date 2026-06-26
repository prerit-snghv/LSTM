# LSTM FPGA Accelerator

Hardware implementation of a fixed-point LSTM inference datapath for a Xilinx
Zedboard-class FPGA.

This project is currently focused on building and verifying a scalar LSTM cell
from reusable RTL blocks. The single-cell datapath, control path, wrapper, and
testbenches are now in place and passing the current golden test cases.

## Current Status

Implemented and verified:

- Fixed-point arithmetic core: `rtl/MAC.sv`, `rtl/Saturation_checker.sv`, `rtl/Processor_top.sv`
- Activation block for sigmoid and tanh: `rtl/ActFn.sv`
- LSTM cell datapath: `rtl/LSTM_cell_dp.sv`
- LSTM cell control FSM: `rtl/LSTM_cell_cp.sv`
- Integrated LSTM cell wrapper: `rtl/LSTM_cell.sv`
- Testbenches for activation, datapath, control path, and integrated cell

The integrated cell testbench currently passes these cases:

- `Nominal_positive`
- `Nominal_negative`
- `Nonzero_u`
- `Nonzero_bias`
- `Near_saturation`

## Architecture

The design uses signed fixed-point arithmetic, generally Q4.12:

- `DATA_WIDTH = 16`
- `ACC_WIDTH = 48`
- `FRACT_WIDTH = 12`
- `1.0 = 4096`

The LSTM equations implemented by the cell are:

```text
i_t = sigmoid(W_i*x_t + U_i*h_prev + b_i)
f_t = sigmoid(W_f*x_t + U_f*h_prev + b_f)
g_t = tanh   (W_g*x_t + U_g*h_prev + b_g)
o_t = sigmoid(W_o*x_t + U_o*h_prev + b_o)
c_t = f_t*c_prev + i_t*g_t
h_t = o_t*tanh(c_t)
```

The implementation is area-oriented. A shared MAC-style processor is reused
across the four gates under control of `LSTM_cell_cp.sv`, rather than computing
all gates in parallel.

## Repository Structure

```text
rtl/      SystemVerilog RTL modules
tb/       SystemVerilog testbenches
scripts/  Helper scripts and golden/reference utilities
docs/     Design notes and architecture summaries
```

## Important RTL Modules

| File | Purpose |
| --- | --- |
| `rtl/MAC.sv` | Sequential fixed-point multiply-accumulate block |
| `rtl/Saturation_checker.sv` | Narrows accumulator output with saturation |
| `rtl/Processor_top.sv` | Wrapper around MAC and saturation logic |
| `rtl/ActFn.sv` | Piecewise polynomial sigmoid/tanh approximation |
| `rtl/LSTM_cell_dp.sv` | LSTM datapath with gate registers and final state computation |
| `rtl/LSTM_cell_cp.sv` | FSM that sequences the datapath micro-operations |
| `rtl/LSTM_cell.sv` | Integrated LSTM cell wrapper connecting CP and DP |
| `rtl/BRAM.sv` | Basic memory utility module |

## Testbenches

| Testbench | Verifies |
| --- | --- |
| `tb/tb_actfn.sv` | Sigmoid/tanh activation behavior |
| `tb/tb_Processor_top.sv` | Arithmetic processor behavior |
| `tb/tb_LSTM_cell_dp.sv` | Datapath math and internal gate sequencing |
| `tb/tb_LSTM_cell_cp.sv` | Control FSM signal sequence |
| `tb/tb_LSTM_cell.sv` | Full CP + DP wrapper behavior |

For the current LSTM milestone, run these first:

```text
tb_LSTM_cell_cp
tb_LSTM_cell_dp
tb_LSTM_cell
```

The wrapper testbench checks:

- reset behavior
- `start` / `done` behavior
- timeout protection
- final `c_t` and `h_t` against golden expected values
- `done` staying high while `start` remains high
- `done` returning low after `start` is deasserted

## Vivado / XSim Environment

Vivado commands such as `vivado`, `xvlog`, `xelab`, and `xsim` are available
after loading the Vivado environment.

Example:

```bash
vivado -version
xvlog -version
```

In Vivado, add the RTL files from `rtl/` and run the desired testbench from
`tb/` as the simulation top.

## Roadmap

Next planned milestones:

1. Freeze the verified single-cell milestone.
2. Build an LSTM sequence controller that runs the cell for multiple timesteps.
3. Feed `h_t` and `c_t` back as `h_prev` and `c_prev` between timesteps.
4. Add input sequence storage for multiple `x_t` values.
5. Add weight and bias storage using registers or BRAM.
6. Build a higher-level `LSTM_top.sv`.
7. Create a top-level testbench for full sequence execution.
8. Run synthesis checks for FPGA readiness.

## Target

- Toolchain: Vivado 2024.x
- FPGA board target: Zedboard / XC7Z020-class device
