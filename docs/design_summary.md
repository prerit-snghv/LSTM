# LSTM FPGA Accelerator Design Summary

This document summarizes what is implemented in the repository today, with a focus on the current LSTM-related datapath. Layer normalization is intentionally excluded here.

## 1. Project Goal

The repository is building a hardware accelerator for LSTM inference on a Xilinx Zedboard-class FPGA. The design direction is a fixed-point, modular datapath where a small reusable arithmetic core is time-multiplexed across LSTM gate computations instead of instantiating a large fully parallel datapath.

At the moment, the center of gravity of the project is not a complete top-level accelerator system. The implemented work is mainly:

- A reusable multiply-accumulate processing block
- Saturation and fixed-point handling
- A polynomial activation block for sigmoid and tanh
- An LSTM cell datapath module that reuses the arithmetic core across the four gates
- Supporting utility modules such as BRAM and a generic mux

## 2. Numerical Format And Arithmetic Policy

The design is using signed fixed-point arithmetic.

- Data path width is generally 16 bits
- Accumulation width is generally 48 bits
- Fractional width is generally 12 bits
- The testbench for the activation function explicitly treats the format as Q4.12

That means:

- `1.0` is represented as `4096`
- `0.5` is represented as `2048`
- `3.0` is represented as `12288`

The arithmetic policy throughout the implemented blocks is:

- Multiply in a wider format
- Shift right by `FRACT_WIDTH` after multiplication to restore the fixed-point scale
- Saturate when narrowing back to 16-bit outputs

This is a sensible FPGA-oriented choice because it keeps the model numerically stable while still staying lightweight enough for DSP-based implementation.

## 3. Current Architectural Direction

The current design is centered around `rtl/LSTM_cell_dp.sv`, which is the only module that really reflects the present LSTM architecture.

The intended LSTM equations are the standard ones:

- `i_t = sigmoid(W_i*x_t + U_i*h_prev + b_i)`
- `f_t = sigmoid(W_f*x_t + U_f*h_prev + b_f)`
- `g_t = tanh(W_g*x_t + U_g*h_prev + b_g)`
- `o_t = sigmoid(W_o*x_t + U_o*h_prev + b_o)`
- `c_t = f_t .* c_prev + i_t .* g_t`
- `h_t = o_t .* tanh(c_t)`

Instead of computing these in parallel, the architecture computes them sequentially under external control.

The design choice is:

- Reuse one MAC-style processing path
- Select the active gate with `gate_sel`
- Select the source operands with mux controls
- Store intermediate gate outputs in internal registers
- Form `c_t` and `h_t` only after all gates are available

This is an area-first architecture. It trades throughput and control simplicity for lower hardware cost and easier early bring-up.

## 4. Module-Level Summary

### 4.1 `Processor_top.sv`

This is the current arithmetic kernel wrapper, not a full chip-level top.

It contains:

- `MAC`
- `Saturation_checker`

Its job is:

- Accept two 16-bit signed fixed-point inputs
- Multiply and accumulate them in a wider accumulator
- Saturate the accumulated result back to 16 bits

So in practice, `Processor_top` is acting as a reusable fixed-point dot-product / pre-activation engine.

### 4.2 `MAC.sv`

This module performs the core multiply-accumulate operation.

Behavior:

- Multiplies `data_in_a * data_in_b`
- Shifts the product right by `FRACT_WIDTH`
- Either clears/restarts accumulation using `clr` or continues accumulation using `en`
- Detects signed overflow on accumulation and saturates the accumulator

Architectural meaning:

- This is the shared engine used to build gate pre-activations such as `W*x + U*h + b`
- The module is sequential because accumulation updates on the clock edge

Important implication:

- The control logic above this block must present operands over multiple cycles in the correct order
- The current project does not yet include a finished controller FSM for this sequencing

### 4.3 `Saturation_checker.sv`

This module narrows the wide accumulator result down to the data width.

Behavior:

- Checks whether the high bits of the accumulator indicate overflow
- Saturates to `0x7FFF` or `0x8000` when necessary
- Otherwise passes through the low `DATA_WIDTH` bits

Architectural role:

- Keeps the shared arithmetic core compatible with 16-bit storage and activation blocks
- Prevents wraparound errors when values exceed the 16-bit range

### 4.4 `ActFn.sv`

This is one of the most complete modules in the repository.

It implements both:

- Sigmoid when `act_fn = 0`
- Tanh when `act_fn = 1`

Key design decision:

- Tanh is not implemented with a separate approximation
- Instead, tanh is derived from sigmoid using `tanh(x) = 2*sigmoid(2x) - 1`

Implementation style:

- Use the absolute value of the input
- Segment the domain into regions
- Use piecewise cubic polynomial coefficients for the sigmoid approximation
- Reconstruct the sign-dependent final result afterward

Segment boundaries are approximately:

- `|x| < 1`
- `1 <= |x| < 3`
- `3 <= |x| < 5`
- `|x| >= 5`

For the last region, the output is forced to the saturated asymptotic value instead of evaluating the polynomial.

Why this matters:

- This avoids LUT-heavy exact nonlinear implementations
- It keeps the activation hardware compact and arithmetic-friendly
- Reusing the sigmoid polynomial for tanh reduces implementation duplication

### 4.5 `LSTM_cell_dp.sv`

This is the real architectural heart of the current design.

Inputs:

- Current input sample `x_t`
- Previous hidden state `h_prev`
- Previous cell state `c_prev`
- Separate scalar weights `W_i/W_f/W_g/W_o`
- Separate recurrent weights `U_i/U_f/U_g/U_o`
- Separate biases `b_i/b_f/b_g/b_o`
- A set of explicit control signals for sequencing the datapath

Internal structure:

- Gate-select logic chooses one gate's parameters at a time
- Operand muxes choose which values feed the shared processing core
- `Processor_top` computes the current gate pre-activation
- `ActFn` converts pre-activation to gate activation
- Registers store `i`, `f`, `g`, `o`, pre-activation, `c_t`, and `h_t`

Control philosophy:

- This module is datapath-only
- An external controller is expected to issue the micro-operations

The important control signals are:

- `gate_sel`: choose `i`, `f`, `g`, or `o`
- `src_a_sel`: choose `W`, `U`, or `b`
- `src_b_sel`: choose `x_t`, `h_prev`, or `c_prev`
- `proc_en` and `proc_clr`: drive the shared processor
- `load_pre_ac`: capture the processor output
- `load_i/load_f/load_g/load_o`: store gate activations
- `load_c/load_h`: commit the final cell and hidden states

Datapath sequencing intent for one gate:

1. Select the gate using `gate_sel`
2. Accumulate `W_* * x_t`
3. Accumulate `U_* * h_prev`
4. Add the bias term
5. Latch the pre-activation
6. Apply the activation function
7. Store into the corresponding gate register

Once the gate registers are available:

- `c_t` is computed as `f_t*c_prev + i_t*g_t`
- `h_t` is computed as `o_t*tanh(c_t)`

Another important design choice:

- The elementwise products for `c_t` and `h_t` are currently implemented directly inside the module with a local saturation helper function
- A comment in the code says this is temporary and may later be replaced by a custom module or a different flow

This tells us the project is still in a bring-up / architecture exploration stage rather than a fully cleaned-up production RTL stage.

### 4.6 `LSTM_cell.sv`

This module is only a stub. It does not currently contribute functionality.

Interpretation:

- The project likely intends to wrap the datapath and a future controller in this module
- That integration has not yet been implemented

### 4.7 `BRAM.sv`

This is a simple synchronous 2K x 16 block RAM wrapper.

Role in the future architecture:

- Likely intended for storing weights, activations, or intermediate vectors
- Currently not integrated into the LSTM datapath

### 4.8 `MUX.sv`

This is a generic operand mux from an earlier architecture phase.

Its inputs suggest it was designed for a more general normalization or iterative arithmetic pipeline, because it includes:

- Raw data input
- Model weight input
- Subtracted data
- LUT data
- MAC feedback

It is not used by the current LSTM cell datapath, which contains its own local operand-selection logic.

## 5. What Has Been Designed So Far

The most accurate way to describe the current design is:

### Designed and meaningfully implemented

- A fixed-point arithmetic policy for 16-bit inference data
- A reusable MAC-plus-saturation processing core
- A nonlinear activation block with polynomial sigmoid and derived tanh
- A datapath for one LSTM cell that computes the four gates sequentially
- Register storage for intermediate gate activations and final `c_t`, `h_t`

### Partially designed or implied, but not finished

- A controller FSM that sequences the LSTM micro-operations
- A fully integrated top-level accelerator around the cell datapath
- Memory orchestration for loading vectors and weights from BRAM
- A complete simulation environment for the current LSTM cell datapath

### Present in repo but not aligned with the latest direction

- Layer-norm-related modules
- An outdated `tb_Processor_top.sv`
- README references to constraints and a Vivado project script that are not currently present

## 6. Architectural Decisions Visible In The Code

These are the main design decisions that have already been made.

### Decision 1: Fixed-point instead of floating-point

The project is clearly targeting FPGA-efficient inference, so all arithmetic is fixed-point. This reduces area and power and fits well with DSP slices.

### Decision 2: Shared arithmetic core instead of four parallel gate datapaths

The same processor block is reused across gate computations. This strongly suggests the design is prioritizing resource efficiency over single-cycle or high-throughput execution.

### Decision 3: Polynomial activations instead of exact math or large lookup tables

The activation block uses segmented cubic approximations. That is a classic hardware tradeoff that balances accuracy, latency, and area.

### Decision 4: Reuse sigmoid hardware to build tanh

This is a deliberate simplification that reduces duplicated approximation logic.

### Decision 5: Datapath-control separation

`LSTM_cell_dp.sv` exposes many explicit load and select signals. That means the architecture is intended to separate:

- datapath hardware
- sequencing/control hardware

This is a good choice for debugging and future FSM refinement.

### Decision 6: Saturation-aware arithmetic throughout

The design consistently handles overflow when reducing precision. That suggests numerical robustness is already being treated as a first-order concern.

## 7. Current Execution Model For One LSTM Time Step

Based on the implemented datapath, one LSTM time step would likely execute like this:

1. Load `x_t`, `h_prev`, and `c_prev`
2. For gate `i`, accumulate `W_i*x_t + U_i*h_prev + b_i`, activate with sigmoid, store in `i_reg`
3. Repeat for gate `f`, store in `f_reg`
4. Repeat for gate `g`, activate with tanh, store in `g_reg`
5. Repeat for gate `o`, store in `o_reg`
6. Compute `c_t = f_t*c_prev + i_t*g_t`
7. Apply tanh to `c_t`
8. Compute `h_t = o_t*tanh(c_t)`
9. Expose `c_t` and `h_t`

So the architecture is effectively a micro-sequenced single-cell inference engine.

## 8. Verification State

The verification state is mixed.

### `tb_actfn.sv`

This is useful and aligned with the current activation module.

It checks:

- Sigmoid mode
- Tanh mode
- Q4.12 expected values
- Tolerance-based pass/fail behavior

This is currently the clearest validation artifact in the repository.

### `tb_Processor_top.sv`

This testbench appears stale relative to the current `Processor_top` interface.

It still expects ports such as:

- `mean_we`
- `var_we`
- `mux_a_sel`
- `mux_b_sel`
- `inv_N`
- `mean_out`
- `var_out`

Those ports do not exist in the current RTL. This means the testbench represents an older architecture phase and should not be treated as proof of correctness for the present design.

## 9. Repository Mismatch And Project Maturity

The repository shows a transition in progress.

Evidence:

- `README.md` still describes a more complete build flow than the repo currently contains
- `LSTM_cell.sv` is only a placeholder
- `LSTM_cell_dp.sv` contains the real current implementation work
- Some modules reflect earlier experiments around normalization and generalized processing
- The most complete verification is concentrated around the activation block

So the best interpretation is:

- The project has moved from earlier arithmetic / normalization exploration into an LSTM-focused datapath implementation
- The current codebase is a working architectural prototype, not yet a fully integrated accelerator

## 10. Practical Bottom Line

If someone needs to understand the project quickly, the core message is:

This repository currently implements the arithmetic backbone of a fixed-point LSTM cell on FPGA. The design uses one shared MAC-based processor, saturation logic, and a piecewise-polynomial activation unit to compute the four LSTM gates sequentially. The most important completed module is `LSTM_cell_dp.sv`, which already captures the intended gate-by-gate datapath and register flow. What is still missing is the surrounding control FSM, memory integration, and a polished top-level system that turns this datapath into a complete deployable accelerator.
