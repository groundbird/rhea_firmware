# MicroBlaze firmware build instructions

## Prerequisites
- Vitis (or Xilinx SDK / mb-gcc toolchain)
- BSP generated from the `rhea_debug_bd` hardware export

## Steps

### 1. Export hardware from Vivado
After generating bitstream in Vivado:
```
File → Export → Export Hardware → Include Bitstream
```
Save as `rhea_debug.xsa`.

### 2. Create BSP in Vitis
```
Vitis → Create Platform Project
  - Select rhea_debug.xsa
  - OS: standalone
  - CPU: microblaze_0
```

### 3. Create Application Project
```
Vitis → Create Application Project
  - Platform: above
  - Template: Empty Application
  - Copy src/debug/firmware/main.c into src/
```

### 4. Build
Click Build (hammer icon) or:
```bash
mb-gcc -O2 -mlittle-endian -mxl-soft-mul main.c \
       -I<platform>/export/bsp/microblaze_0/include \
       -L<platform>/export/bsp/microblaze_0/lib \
       -lxil -Wl,-T,<platform>/export/bsp/microblaze_0/lscript.ld \
       -o main.elf
```

### 5. Program and connect JTAG UART

#### Option A – Vitis (GUI)
- Right-click project → Run As → Launch on Hardware
- Open Vitis Serial Terminal (or Xilinx JTAG UART terminal)

#### Option B – xsct (command line)
```tcl
xsct% connect
xsct% targets
# Find MicroBlaze target (usually target 3 or 4)
xsct% target 3
xsct% fpga -f <path>/rhea_debug.bit
xsct% dow main.elf
xsct% con
xsct% jtagterminal
```

You will see the menu:
```
====================================
  rhea debug firmware (MicroBlaze)
====================================
 1 : Check clk_ab (FMC 200 MHz clock)
 2 : Test DAC3283 SPI (read ID/version)
 3 : Test ADS4249 SPI (read device ID)
...
```

## Expected results

### clk_ab check (command 1)
- `MMCM locked : LOCKED` → 200 MHz clock is present on FMC
- `Freq counter : ~262144 counts (est. ~200000 kHz)` → confirms frequency
- If `NOT LOCKED`: clock not present, check FMC power and board connection

### DAC3283 SPI test (command 2)
- `Reg[0x01] = 0x?? (non-zero, non-FF)` → SPI communication working
- If `0xFF` or `0x00`: check spi_sclk18, spi_sdata18, dac_n_en18, dac_sdo18 pins

### ADS4249 SPI test (command 3)
- `Reg[0x00] = 0x49` → ADS4249 identified correctly
- If unexpected value: check CPOL (mode 2), adc_n_en18, adc_sdo18 pins
