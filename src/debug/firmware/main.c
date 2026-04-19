/*
 * main.c  –  rhea debug firmware for MicroBlaze (JTAG UART via MDM)
 *
 * Verifies:
 *   1. FMC clk_ab_p/n 200 MHz presence (MMCM lock + frequency counter)
 *   2. SPI register access to DAC3283 (slave 1) and ADS4249 (slave 0)
 *
 * Build with Vitis / mb-gcc:
 *   mb-gcc -O2 -mlittle-endian -mxl-soft-mul main.c \
 *          -I<BSP>/include -L<BSP>/lib -lxil -o main.elf
 *
 * JTAG UART access:
 *   xsct% connect
 *   xsct% targets          # find MicroBlaze target number
 *   xsct% target <N>
 *   xsct% dow main.elf
 *   xsct% con
 *   xsct% jtagterminal     # opens interactive terminal
 *
 * GPIO register map (AXI GPIO base = 0x4000_0000):
 *   0x4000_0000  GPIO1 DATA  (write: SPI ctrl + LEDs)
 *   0x4000_0004  GPIO1 TRI   (must be 0x00 = all output)
 *   0x4000_0008  GPIO2 DATA  (read:  status + freq count)
 *   0x4000_000C  GPIO2 TRI   (must be 0xFF_FFFF = all input)
 *
 * GPIO1 output bits [7:0]:
 *   [0] SCLK       → spi_sclk18
 *   [1] MOSI       → spi_sdata18
 *   [2] ADC_CS_N   → adc_n_en18  (active-low)
 *   [3] DAC_CS_N   → dac_n_en18  (active-low)
 *   [7:4] LEDs
 *
 * GPIO2 input bits [23:0]:
 *   [0]    ADC_SDO      (adc_sdo18)
 *   [1]    DAC_SDO      (dac_sdo18)
 *   [2]    CLK_LOCKED   (MMCM locked on clk_ab)
 *   [22:3] FREQ_COUNT   (clk_freq_counter count_out[19:0])
 */

#include <stdlib.h>
#include "xil_printf.h"
#include "xil_io.h"
#include "sleep.h"

/* -----------------------------------------------------------------------
 * Register addresses
 * ----------------------------------------------------------------------- */
#define GPIO_BASE       0x40000000UL
#define GPIO1_DATA      (GPIO_BASE + 0x00)   /* output */
#define GPIO1_TRI       (GPIO_BASE + 0x04)   /* direction: 0=out */
#define GPIO2_DATA      (GPIO_BASE + 0x08)   /* input */
#define GPIO2_TRI       (GPIO_BASE + 0x0C)   /* direction: all 1 = input */

/* GPIO1 bit positions */
#define BIT_SCLK        (1u << 0)
#define BIT_MOSI        (1u << 1)
#define BIT_ADC_CS_N    (1u << 2)
#define BIT_DAC_CS_N    (1u << 3)
#define LED_SHIFT       4

/* GPIO2 bit positions */
#define BIT_ADC_SDO     (1u << 0)
#define BIT_DAC_SDO     (1u << 1)
#define BIT_CLK_LOCKED  (1u << 2)
#define FREQ_COUNT_SHIFT 3
#define FREQ_COUNT_MASK  0xFFFFF    /* 20 bits */

/* SPI clock half-period: ~5 us each side → ~100 kHz */
#define SPI_HALF_US     5

/* -----------------------------------------------------------------------
 * Low-level GPIO helpers
 * ----------------------------------------------------------------------- */
static inline void gpio1_write(u32 val)
{
    Xil_Out32(GPIO1_DATA, val);
}

static inline u32 gpio1_read(void)
{
    return Xil_In32(GPIO1_DATA);
}

static inline u32 gpio2_read(void)
{
    return Xil_In32(GPIO2_DATA);
}

static void gpio_init(void)
{
    Xil_Out32(GPIO1_TRI, 0x00000000);    /* all GPIO1 = output */
    Xil_Out32(GPIO2_TRI, 0x00FFFFFF);    /* all GPIO2 = input  */
    /* Initial state: both CS deasserted, SCLK=0, MOSI=0, all LEDs off */
    gpio1_write(BIT_ADC_CS_N | BIT_DAC_CS_N);
}

/* -----------------------------------------------------------------------
 * SPI bit-bang
 *
 * DAC3283:  CPOL=0 CPHA=0  (SPI mode 0) – clock idles low, sample on rise
 * ADS4249:  CPOL=1 CPHA=0  (SPI mode 2) – clock idles high, sample on fall
 *
 * Both devices use 16-bit transfers:
 *   DAC3283:  bit15 = R/W (0=write,1=read), bits14:8 = addr, bits7:0 = data
 *   ADS4249:  bit15:8 = addr, bit7:0 = data  (read sets bit15=1? see DS)
 *
 * We handle CPOL by setting SCLK idle to CPOL before asserting CS.
 * ----------------------------------------------------------------------- */

/* spi_sel: 0=ADC (ADS4249, CPOL=1), 1=DAC (DAC3283, CPOL=0) */
static u16 spi_transfer16(int spi_sel, u16 tx_data)
{
    u32 cs_bit   = (spi_sel == 0) ? BIT_ADC_CS_N : BIT_DAC_CS_N;
    u32 cpol     = (spi_sel == 0) ? 1 : 0;  /* CPOL */
    u32 idle_clk = cpol ? BIT_SCLK : 0;

    u32 base = BIT_ADC_CS_N | BIT_DAC_CS_N;  /* both CS deasserted */
    u16 rx_data = 0;

    /* Set idle clock, keep both CS high */
    gpio1_write(base | idle_clk);
    usleep(SPI_HALF_US);

    /* Assert CS (deassert the other one, set idle clock) */
    gpio1_write((base & ~cs_bit) | idle_clk);
    usleep(SPI_HALF_US);

    for (int i = 15; i >= 0; i--) {
        u32 mosi_bit = ((tx_data >> i) & 1) ? BIT_MOSI : 0;

        if (cpol == 0) {
            /* Mode 0: data valid on rising edge */
            /* Output data, SCLK low */
            gpio1_write((base & ~cs_bit) | mosi_bit);
            usleep(SPI_HALF_US);
            /* SCLK high – slave samples here */
            gpio1_write((base & ~cs_bit) | mosi_bit | BIT_SCLK);
            usleep(SPI_HALF_US);
        } else {
            /* Mode 2: data valid on falling edge */
            /* SCLK high, output data */
            gpio1_write((base & ~cs_bit) | mosi_bit | BIT_SCLK);
            usleep(SPI_HALF_US);
            /* SCLK low – slave samples here */
            gpio1_write((base & ~cs_bit) | mosi_bit);
            usleep(SPI_HALF_US);
        }

        /* Sample MISO */
        u32 miso_bit = (spi_sel == 0) ?
            (gpio2_read() & BIT_ADC_SDO) : (gpio2_read() & BIT_DAC_SDO);
        if (miso_bit)
            rx_data |= (1u << i);
    }

    /* Deassert CS, restore idle clock */
    gpio1_write(base | idle_clk);
    usleep(SPI_HALF_US);
    gpio1_write(base);

    return rx_data;
}

/* -----------------------------------------------------------------------
 * DAC3283 helpers
 * Mode 0 (CPOL=0).
 * SPI frame (16-bit):
 *   [15]    = R/W  (0=write, 1=read)
 *   [14:13] = 00   (fixed, per DAC3283 datasheet / spi_master_wrapper.vhd)
 *   [12:8]  = addr (5-bit, A4:A0)
 *   [7:0]   = data
 *
 * 4-wire SPI enable:
 *   Reg 0x00 (CONFIG_A), bit4 SIF4_ENA = 1 → SDO pin driven (4-wire mode)
 *   Must be written BEFORE any read, while still in 3-wire mode.
 * ----------------------------------------------------------------------- */
static void dac3283_write(u8 addr, u8 data)
{
    /* bit15=0(write), bit14:13=00, bit12:8=addr[4:0], bit7:0=data */
    u16 tx = (u16)(((addr & 0x1F) << 8) | data);
    spi_transfer16(1, tx);
}

static void dac3283_enable_4wire(void)
{
    /* Reg 0x17, bit2 = SIF4_ENA: 1 → SDO pin driven (4-wire mode) */
    dac3283_write(0x17, 0x04);
    usleep(10);
}

static u8 dac3283_read(u8 addr)
{
    /* bit15=1(read), bit14:13=00, bit12:8=addr[4:0], bit7:0=0 */
    u16 tx = (u16)(0x8000 | ((addr & 0x1F) << 8));
    u16 rx = spi_transfer16(1, tx);
    return (u8)(rx & 0xFF);
}

/* -----------------------------------------------------------------------
 * ADS4249 helpers
 * Mode 2 (CPOL=1, CPHA=0). 16-bit: [15:8]=addr (8-bit), [7:0]=data
 *
 * Read-back procedure (per ADS4249 datasheet Figure 45):
 *   1. Write READOUT=1 to reg 0x00 bit0  → enables SDOUT, disables other writes
 *   2. Send target register address (8-bit) + dummy data → SDOUT outputs reg content
 *   3. Write READOUT=0 to reg 0x00 bit0  → re-enables writes
 *
 * Note: address is full 8-bit (e.g. 0xD5 is valid). Do NOT mask with 0x7F.
 * ----------------------------------------------------------------------- */
static void ads4249_write(u8 addr, u8 data)
{
    u16 tx = (u16)(((u16)addr << 8) | data);
    spi_transfer16(0, tx);
}

static void ads4249_enable_readout(void)
{
    /* Reg 0x00, bit0 = READOUT: 1 → SDOUT pin driven, further writes disabled */
    ads4249_write(0x00, 0x01);
    usleep(10);
}

static void ads4249_disable_readout(void)
{
    /* Reg 0x00, bit0 = READOUT: 0 → SDOUT Hi-Z, writes re-enabled */
    ads4249_write(0x00, 0x00);
    usleep(10);
}

static u8 ads4249_read(u8 addr)
{
    ads4249_enable_readout();
    /* Send address (no R/W bit); SDOUT outputs register content during this cycle */
    u16 tx = (u16)((u16)addr << 8);
    u16 rx = spi_transfer16(0, tx);
    ads4249_disable_readout();
    return (u8)(rx & 0xFF);
}

/* -----------------------------------------------------------------------
 * Clock status
 * ----------------------------------------------------------------------- */
static void print_clk_status(void)
{
    u32 gpio2 = gpio2_read();
    int locked = (gpio2 & BIT_CLK_LOCKED) ? 1 : 0;
    u32 count  = (gpio2 >> FREQ_COUNT_SHIFT) & FREQ_COUNT_MASK;

    /* count is edges captured in 2^17 = 131072 mb_clk cycles @ 100 MHz
     * Expected at 200 MHz input: ~262144 (0x40000)
     * Frequency estimate: count * 100e6 / 131072  Hz */
    u32 freq_khz = (u32)((u64)count * 100000ULL / 131072ULL);

    xil_printf("\r\n=== clk_ab status ===\r\n");
    xil_printf("  MMCM locked   : %s\r\n", locked ? "LOCKED" : "NOT LOCKED");
    xil_printf("  Freq counter  : %lu counts (est. %lu kHz)\r\n",
               (unsigned long)count, (unsigned long)freq_khz);
    if (locked && freq_khz > 190000 && freq_khz < 210000)
        xil_printf("  Result        : OK – 200 MHz clock present\r\n");
    else if (!locked)
        xil_printf("  Result        : FAIL – MMCM not locked (no clock or wrong freq)\r\n");
    else
        xil_printf("  Result        : WARNING – locked but freq unexpected\r\n");
}

/* -----------------------------------------------------------------------
 * SPI test: read chip ID / known register
 * ----------------------------------------------------------------------- */

/* DAC3283: register 0x00 = device version (expect 0x2X on rev B) */
static void test_dac3283(void)
{
    xil_printf("\r\n=== DAC3283 SPI test ===\r\n");

    /* Enable 4-wire SPI mode first (SDO pin tri-stated until this is set) */
    dac3283_enable_4wire();
    xil_printf("  4-wire SPI enabled (SIF4_ENA=1)\r\n");

    /* Read back device version register (0x01 on DAC3283) */
    u8 ver  = dac3283_read(0x01);
    /* Read default FIFO register */
    u8 fifo = dac3283_read(0x07);

    xil_printf("  Reg[0x01] (version)  = 0x%02X\r\n", ver);
    xil_printf("  Reg[0x07] (FIFO cfg) = 0x%02X\r\n", fifo);

    if (ver != 0xFF && ver != 0x00)
        xil_printf("  Result : OK – device responding\r\n");
    else
        xil_printf("  Result : FAIL – no response (0x%02X)\r\n", ver);
}

/* ADS4249: reads use READOUT mode (reg 0x00 bit0).
 * ads4249_read() handles enable/disable automatically. */
static void test_ads4249(void)
{
    xil_printf("\r\n=== ADS4249 SPI test ===\r\n");
    usleep(100);

    /* Read device ID register */
    u8 id   = ads4249_read(0x00);
    /* Read default high-perf mode register (0x03) */
    u8 hpm  = ads4249_read(0x03);

    xil_printf("  Reg[0x00] (device ID)  = 0x%02X (expect 0x49)\r\n", id);
    xil_printf("  Reg[0x03] (HP mode)    = 0x%02X\r\n", hpm);

    if (id == 0x49)
        xil_printf("  Result : OK – ADS4249 identified\r\n");
    else if (id != 0xFF && id != 0x00)
        xil_printf("  Result : PARTIAL – device responding but unexpected ID\r\n");
    else
        xil_printf("  Result : FAIL – no response (0x%02X)\r\n", id);
}

/* -----------------------------------------------------------------------
 * Interactive SPI register read/write
 * ----------------------------------------------------------------------- */
static int read_hex_byte(const char *prompt)
{
    xil_printf("%s (hex, 2 digits): ", prompt);
    char buf[4] = {0};
    for (int i = 0; i < 2; ) {
        int c = inbyte();
        if (c == '\r' || c == '\n') break;
        if ((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')) {
            buf[i++] = (char)c;
            outbyte(c);  /* echo */
        }
    }
    xil_printf("\r\n");
    return (int)strtol(buf, NULL, 16);
}

static void interactive_spi(int spi_sel)
{
    const char *name = (spi_sel == 0) ? "ADS4249" : "DAC3283";
    xil_printf("\r\n--- %s interactive SPI ---\r\n", name);

    /* DAC3283: enable ALARM_SDO output (4-wire). ADS4249: ads4249_read() handles READOUT internally. */
    if (spi_sel == 1) dac3283_enable_4wire();

    xil_printf("Commands: r=read  w=write  q=quit\r\n");

    while (1) {
        xil_printf("> ");
        int c = inbyte();
        outbyte(c);
        xil_printf("\r\n");

        if (c == 'q' || c == 'Q') break;
        if (c == 'r' || c == 'R') {
            int addr = read_hex_byte("  Addr");
            u8 val = (spi_sel == 0) ? ads4249_read(addr) : dac3283_read(addr);
            xil_printf("  [0x%02X] = 0x%02X\r\n", addr, val);
        } else if (c == 'w' || c == 'W') {
            int addr = read_hex_byte("  Addr");
            int data = read_hex_byte("  Data");
            if (spi_sel == 0) ads4249_write(addr, data);
            else              dac3283_write(addr, data);
            xil_printf("  Wrote 0x%02X → [0x%02X]\r\n", data, addr);
        }
    }
}

/* -----------------------------------------------------------------------
 * LED blink (uses GPIO1 bits [7:4])
 * ----------------------------------------------------------------------- */
static void set_leds(u8 pattern)
{
    u32 cur = gpio1_read() & 0x0F;  /* keep lower nibble (SPI/CS) */
    gpio1_write(cur | ((u32)(pattern & 0x0F) << LED_SHIFT));
}

/* -----------------------------------------------------------------------
 * Main menu
 * ----------------------------------------------------------------------- */
static void print_menu(void)
{
    xil_printf("\r\n");
    xil_printf("====================================\r\n");
    xil_printf("  rhea debug firmware (MicroBlaze)\r\n");
    xil_printf("====================================\r\n");
    xil_printf(" 1 : Check clk_ab (FMC 200 MHz clock)\r\n");
    xil_printf(" 2 : Test DAC3283 SPI (read ID/version)\r\n");
    xil_printf(" 3 : Test ADS4249 SPI (read device ID)\r\n");
    xil_printf(" 4 : Interactive SPI – DAC3283\r\n");
    xil_printf(" 5 : Interactive SPI – ADS4249\r\n");
    xil_printf(" 6 : Run all tests\r\n");
    xil_printf(" l : Toggle LEDs (blink pattern)\r\n");
    xil_printf(" ? : Show this menu\r\n");
    xil_printf("====================================\r\n");
    xil_printf("> ");
}

int main(void)
{
    gpio_init();

    /* Flash LEDs to show firmware is alive */
    for (int i = 0; i < 4; i++) {
        set_leds(0x0F);
        usleep(100000);
        set_leds(0x00);
        usleep(100000);
    }
    set_leds(0x01);  /* LED0 on = running */

    print_menu();

    u8 led_pat = 1;

    while (1) {
        int c = inbyte();
        outbyte(c);
        xil_printf("\r\n");

        switch (c) {
        case '1':
            print_clk_status();
            break;
        case '2':
            test_dac3283();
            break;
        case '3':
            test_ads4249();
            break;
        case '4':
            interactive_spi(1);  /* DAC3283 */
            break;
        case '5':
            interactive_spi(0);  /* ADS4249 */
            break;
        case '6':
            print_clk_status();
            test_dac3283();
            test_ads4249();
            break;
        case 'l':
        case 'L':
            led_pat = (led_pat == 0x0F) ? 0x01 : (led_pat << 1) | 0x01;
            set_leds(led_pat);
            xil_printf("  LEDs = 0x%X\r\n", led_pat);
            break;
        case '?':
        default:
            break;
        }

        print_menu();
    }

    return 0;
}
