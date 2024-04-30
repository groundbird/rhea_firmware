# Firmware for KIDs Readout System (RHEA and KCU105)

## Overview
This repository hosts the firmware designed for the Kinetic Inductance Detectors (KIDs) readout system utilizing the RHEA analog board and Xilinx's KCU105 FPGA board. Key features include:
- DDS (Direct Digital Synthesizer) and an adder to synthesize multi-tone waves for KIDs.
- DDC (Digital Down Converter) for channelization of the returning wave from KIDs.

## Requirements
- **Development Environment**: Vivado 2018.3 on Windows 10
- **Hardware**: Xilinx KCU105 FPGA board, RHEA analog board
- **Software Dependencies**: This firmware utilizes SiTCP for Kintex Ultrascale devices and an RBCP to AXI interface converter as submodules.

## Installation
1. Clone this repository recursively to include submodules:
   ```bash
   git clone --recursive [repository-url]
   ```
2. Install Vivado 2018.3 if not already installed.

## Usage
1. Launch Vivado using the provided TCL script:
   ```bash
   vivado -mode batch -source rhea-fpga.tcl
   ```
2. Open Vivado in GUI mode to gnerate the bitstream as required.

Find the software required to operate this firmware at [groundbird/rhea_comm](https://github.com/groundbird/rhea_comm).
