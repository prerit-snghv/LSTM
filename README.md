URECA 25-26

# LSTM FPGA Accelerator

Hardware implementation of LSTM inference on Zedboard FPGA.

## Structure

rtl/            RTL modules  
tb/             Testbenches  
constraints/    FPGA constraints  
scripts/        scripts  

## Requirements

Vivado 2024.x 
Zedboard (xc7z020)

## Vivado Command-Line Environment

Vivado commands such as `vivado`, `xvlog`, `xelab`, and `xsim` are only
available after loading the Vivado environment.

### From VS Code

Open a new integrated terminal. The workspace is configured to use the
`Vivado Git Bash` profile by default, which:

1. Loads `C:\Xilinx\Vivado\2024.1\settings64.bat`
2. Opens Git Bash with the Vivado tools available
3. Loads the shell setup from `.vscode/vivado_git_bash_init.sh`

Verify the environment:

```bash
vivado -version
xvlog -version
```

The predefined simulation tasks can also be run from:

```text
Command Palette > Tasks: Run Task
```

Available tasks include `XSim: Run tb_actfn` and
`XSim: Run tb_Processor_top`. Each run task automatically performs its
compile and elaboration dependencies first.

### From Command Prompt

Load the Vivado environment in the current Command Prompt:

```bat
call C:\Xilinx\Vivado\2024.1\settings64.bat
vivado -version
```

To open the repository's configured Vivado Git Bash environment instead:

```bat
.vscode\vivado_git_bash_init.bat
```

If Vivado or the shared `vivado_env.bat` wrapper is installed elsewhere,
update the paths in `.vscode/vivado_git_bash_init.bat` and
`.vscode/tasks.json`.

## Build

vivado -source scripts/create_project.tcl 
