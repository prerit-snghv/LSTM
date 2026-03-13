# URECA 25-26

## LSTM FPGA Accelerator

Hardware implementation of LSTM inference on Zedboard FPGA.

## Structure

rtl/        RTL modules  
tb/         Testbenches  
constraints/ FPGA constraints  
scripts/    Vivado project generation scripts  

## Requirements

Vivado 2024.x  
Zedboard (xc7z020)

## Build

vivado -source scripts/create_project.tcl
