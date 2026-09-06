# SiTCP EEPROM bring-up on AXKU042

Notes for the case where SiTCP works with force-default but not in normal mode.

## What the symptom means

Simulation of the SiTCP netlist together with the AT93C46_LC04 bridge and a
24LC04 model showed three distinct behaviours:

| EEPROM contents | What SiTCP does |
| --- | --- |
| any (force-default mode) | never reads the EEPROM at all, uses its built-in defaults |
| valid parameters, invalid licence area | loads MAC/IP/ports, releases its reset briefly, then resets and re-reads for ever |
| blank (0xFF) | stops after the first three MAC bytes and never releases its reset |

So "force default works, normal mode does not" points at the EEPROM contents,
not at the bridge.  The bridge itself returned every byte correctly over
several hundred transactions in the same simulation.

The 24LC04 needs the whole 128-byte parameter block, not only the licence:
control byte, MAC, IP, ports, MSS and every timer at 0x24-0x2F.

## What this design gives you

### Over JTAG (VIO), works even when SiTCP never comes up

| Probe | Meaning |
| --- | --- |
| `probe_in0` | shadow RAM byte at `probe_out0` |
| `probe_in1` | bridge status, same bits as RBCP 0x200 |
| `probe_in2` | MAC address SiTCP loaded |
| `probe_in3` | IP address SiTCP loaded |
| `probe_in4` | TCP main port |
| `probe_in5` | RBCP port |
| `probe_in6` | SiTCP self-reset count |
| `probe_out0` | shadow RAM address to inspect |
| `probe_out1[0]` | override `force_defaultn` |
| `probe_out1[1]` | `force_defaultn` value while the override is on |
| `probe_out1[2]` | soft reset for SiTCP and the bridge |
| `probe_out1[3]` | queue one EEPROM byte (rising edge) |
| `probe_out1[4]` | re-read the EEPROM (rising edge) |
| `probe_out2` | EEPROM address to write |
| `probe_out3` | EEPROM data to write |

A self-reset count that keeps climbing while the board sits idle is the reset
loop, and it means SiTCP rejected the image it read.

### Over RBCP, usable while running in force-default mode

| Address | Access | Meaning |
| --- | --- | --- |
| 0x0000_0100 | R | bridge status |
| 0x0000_0180-0x0000_01FF | R | shadow RAM, 128 bytes |
| 0x0000_0200 | R | bridge status |
| 0x0000_0201 | R | SiTCP self-reset count |
| 0x0000_0202-0x0000_0207 | R | MAC address, most significant byte first |
| 0x0000_0208-0x0000_020B | R | IP address |
| 0x0000_020C-0x0000_020D | R | TCP main port |
| 0x0000_020E-0x0000_020F | R | RBCP port |
| 0x0000_0210 | R/W | byte to write |
| 0x0000_0211 | R/W | EEPROM address to write, 0-127 |
| 0x0000_0212 | W | write 0xA5 to queue the byte into the 24LC04 |
| 0x0000_0213 | W | write 0x5A to re-read the EEPROM and restart SiTCP |

The status byte is
`{force_defaultn, write busy, write error, write done, bridge reset, SiTCP held in reset, read error, read done}`.

## Repair procedure

1. Hold the user key so `force_defaultn` is low, or set the VIO override, then
   reset.  SiTCP comes up on 192.168.10.16 with RBCP on port 4660.
2. Read 0x0000_0180-0x0000_01FF and compare against a known-good dump.
3. For every byte that differs, write 0x0210 and 0x0211, then write 0xA5 to
   0x0212.  Poll the write-busy bit in 0x0200 before the next byte.
4. Write 0x5A to 0x0213.  The reader re-reads the EEPROM and cycles SiTCP, so
   the new values take effect without a power cycle.  RBCP drops for about
   15 ms while this happens, so expect one lost acknowledgement.
5. Release force-default and reset.  Read 0x0202-0x020F to confirm SiTCP now
   loads the values you wrote, and watch that 0x0201 stays at zero.

This path never uses SiTCP's own 0xFFFF_FCxx EEPROM window, which is
unreachable exactly when the parameter block is broken.

## Robustness changes

- `LC04_READER` gives up after `RETRY_MAX` unanswered transactions instead of
  retrying for ever.  An unresponsive EEPROM used to hold the entire design in
  reset with no indication of why; now the error bit latches and the rest of
  the design runs.
- A reload resets only the reader, so bytes already queued for the 24LC04
  survive it and are not written twice.
- The one-shot delayed reset in `rhea.vhd` fires about 5.4 s after power-up and
  restarts the bridge.  Issue maintenance writes after that point.
