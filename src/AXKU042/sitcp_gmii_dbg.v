`timescale 1ns / 1ps
//------------------------------------------------------------------------------
//  Module      : sitcp_gmii_dbg
//
//  Drop-in replacement for WRAP_SiTCP_GMII_XCKU_32K that additionally exposes
//  the network parameters SiTCP actually loaded from the EEPROM.
//
//  The vendor wrapper (submodule src/XCKUSiTCPlib32k_11V) ties MY_MAC_ADDR and
//  the *_DEFAULT outputs of SiTCP_XCKU_32K_BBT_V110 to nothing, so there is no
//  way to tell "the EEPROM was read correctly" from "SiTCP accepted the values".
//  This wrapper keeps the vendor instantiation identical and only routes those
//  outputs to ports, so they can be observed over VIO / RBCP.
//
//  Port list and semantics are otherwise the same as the vendor wrapper.
//  The submodule is left untouched so it stays updatable from upstream.
//------------------------------------------------------------------------------

module sitcp_gmii_dbg #(
    parameter [7:0] TIM_PERIOD = 8'd200   // system clock frequency in MHz
) (
    input  wire        CLK,
    input  wire        RST,
    // Configuration
    input  wire        FORCE_DEFAULTn,
    input  wire [31:0] EXT_IP_ADDR,
    input  wire [15:0] EXT_TCP_PORT,
    input  wire [15:0] EXT_RBCP_PORT,
    input  wire [4:0]  PHY_ADDR,
    // Parameters as loaded by SiTCP (debug observation)
    output wire [47:0] MY_MAC_ADDR,
    output wire [31:0] IP_ADDR_DEFAULT,
    output wire [15:0] TCP_MAIN_PORT_DEFAULT,
    output wire [15:0] RBCP_PORT_DEFAULT,
    // EEPROM (AT93C46 serial interface)
    output wire        EEPROM_CS,
    output wire        EEPROM_SK,
    output wire        EEPROM_DI,
    input  wire        EEPROM_DO,
    output wire [7:0]  USR_REG_X3C,
    output wire [7:0]  USR_REG_X3D,
    output wire [7:0]  USR_REG_X3E,
    output wire [7:0]  USR_REG_X3F,
    // GMII
    output wire        GMII_RSTn,
    input  wire        GMII_1000M,
    input  wire        GMII_TX_CLK,
    output wire        GMII_TX_EN,
    output wire [7:0]  GMII_TXD,
    output wire        GMII_TX_ER,
    input  wire        GMII_RX_CLK,
    input  wire        GMII_RX_DV,
    input  wire [7:0]  GMII_RXD,
    input  wire        GMII_RX_ER,
    input  wire        GMII_CRS,
    input  wire        GMII_COL,
    output wire        GMII_MDC,
    input  wire        GMII_MDIO_IN,
    output wire        GMII_MDIO_OUT,
    output wire        GMII_MDIO_OE,
    // User I/F
    output wire        SiTCP_RST,
    input  wire        TCP_OPEN_REQ,
    output wire        TCP_OPEN_ACK,
    output wire        TCP_ERROR,
    output wire        TCP_CLOSE_REQ,
    input  wire        TCP_CLOSE_ACK,
    input  wire [15:0] TCP_RX_WC,
    output wire        TCP_RX_WR,
    output wire [7:0]  TCP_RX_DATA,
    output wire        TCP_TX_FULL,
    input  wire        TCP_TX_WR,
    input  wire [7:0]  TCP_TX_DATA,
    // RBCP
    output wire        RBCP_ACT,
    output wire [31:0] RBCP_ADDR,
    output wire [7:0]  RBCP_WD,
    output wire        RBCP_WE,
    output wire        RBCP_RE,
    input  wire        RBCP_ACK,
    input  wire [7:0]  RBCP_RD
);

    wire TIM_1US, TIM_1MS, TIM_1S, TIM_1MIN;

    TIMER #(TIM_PERIOD - 8'd2) TIMER (
        .CLK     (CLK     ),   // in : System clock
        .RST     (RST     ),   // in : System reset
        .TIM_1US (TIM_1US ),   // out: 1 us interval
        .TIM_1MS (TIM_1MS ),   // out: 1 ms interval
        .TIM_1S  (TIM_1S  ),   // out: 1 s interval
        .TIM_1M  (TIM_1MIN)    // out: 1 min interval
    );

    // Same selection logic as the vendor wrapper: an EXT_* value of zero means
    // "use the register value", and FORCE_DEFAULTn=0 always uses the register.
    wire [15:0] MY_TCP_PORT  = (~FORCE_DEFAULTn | (EXT_TCP_PORT  == 16'd0)) ? TCP_MAIN_PORT_DEFAULT : EXT_TCP_PORT;
    wire [15:0] MY_RBCP_PORT = (~FORCE_DEFAULTn | (EXT_RBCP_PORT == 16'd0)) ? RBCP_PORT_DEFAULT     : EXT_RBCP_PORT;
    wire [31:0] MY_IP_ADDR   = (~FORCE_DEFAULTn | (EXT_IP_ADDR   == 32'd0)) ? IP_ADDR_DEFAULT       : EXT_IP_ADDR;

    wire [47:0] TCP_SERVER_MAC;
    wire [31:0] TCP_SERVER_ADDR;
    wire [15:0] TCP_SERVER_PORT;

    wire TCP_OPEN_ERROR;
    wire TCP_TX_OW_ERROR;
    assign TCP_ERROR = TCP_OPEN_ERROR | TCP_TX_OW_ERROR;

    SiTCP_XCKU_32K_BBT_V110 SiTCP (
        .CLK                     (CLK                   ),
        .RST                     (RST                   ),
        .TIM_1US                 (TIM_1US               ),
        .TIM_1MS                 (TIM_1MS               ),
        .TIM_1S                  (TIM_1S                ),
        .TIM_1M                  (TIM_1MIN              ),
        .FORCE_DEFAULTn          (FORCE_DEFAULTn        ),
        .MODE_GMII               (1'b1                  ),
        .MIN_RX_IPG              (4'd4                  ),
        .IP_ADDR_IN              (MY_IP_ADDR            ),
        .IP_ADDR_DEFAULT         (IP_ADDR_DEFAULT       ),
        .MY_MAC_ADDR             (MY_MAC_ADDR           ),
        .TCP_MAIN_PORT_IN        (MY_TCP_PORT           ),
        .TCP_MAIN_PORT_DEFAULT   (TCP_MAIN_PORT_DEFAULT ),
        .TCP_SUB_PORT_IN         (16'd0                 ),
        .TCP_SUB_PORT_DEFAULT    (                      ),
        .TCP_SERVER_MAC_IN       (TCP_SERVER_MAC        ),
        .TCP_SERVER_MAC_DEFAULT  (TCP_SERVER_MAC        ),
        .TCP_SERVER_ADDR_IN      (TCP_SERVER_ADDR       ),
        .TCP_SERVER_ADDR_DEFAULT (TCP_SERVER_ADDR       ),
        .TCP_SERVER_PORT_IN      (TCP_SERVER_PORT       ),
        .TCP_SERVER_PORT_DEFAULT (TCP_SERVER_PORT       ),
        .RBCP_PORT_IN            (MY_RBCP_PORT          ),
        .RBCP_PORT_DEFAULT       (RBCP_PORT_DEFAULT     ),
        .PHY_ADDR                (PHY_ADDR              ),
        .EEPROM_CS               (EEPROM_CS             ),
        .EEPROM_SK               (EEPROM_SK             ),
        .EEPROM_DI               (EEPROM_DI             ),
        .EEPROM_DO               (EEPROM_DO             ),
        .USR_REG_X3C             (USR_REG_X3C           ),
        .USR_REG_X3D             (USR_REG_X3D           ),
        .USR_REG_X3E             (USR_REG_X3E           ),
        .USR_REG_X3F             (USR_REG_X3F           ),
        .GMII_1000M              (GMII_1000M            ),
        .GMII_RSTn               (GMII_RSTn             ),
        .GMII_TX_CLK             (GMII_TX_CLK           ),
        .GMII_TX_EN              (GMII_TX_EN            ),
        .GMII_TXD                (GMII_TXD              ),
        .GMII_TX_ER              (GMII_TX_ER            ),
        .GMII_RX_CLK             (GMII_RX_CLK           ),
        .GMII_RX_DV              (GMII_RX_DV            ),
        .GMII_RXD                (GMII_RXD              ),
        .GMII_RX_ER              (GMII_RX_ER            ),
        .GMII_CRS                (GMII_CRS              ),
        .GMII_COL                (GMII_COL              ),
        .GMII_MDC                (GMII_MDC              ),
        .GMII_MDIO_IN            (GMII_MDIO_IN          ),
        .GMII_MDIO_OUT           (GMII_MDIO_OUT         ),
        .GMII_MDIO_OE            (GMII_MDIO_OE          ),
        .SiTCP_RST               (SiTCP_RST             ),
        .OPEN_REQ                (TCP_OPEN_REQ          ),
        .MAIN_OPEN_ACK           (TCP_OPEN_ACK          ),
        .SUB_OPEN_ACK            (                      ),
        .TCP_OPEN_ERROR          (TCP_OPEN_ERROR        ),
        .TCP_TX_OW_ERROR         (TCP_TX_OW_ERROR       ),
        .CLOSE_REQ               (TCP_CLOSE_REQ         ),
        .CLOSE_ACK               (TCP_CLOSE_ACK         ),
        .RX_FILL                 (TCP_RX_WC             ),
        .RX_WR                   (TCP_RX_WR             ),
        .RX_DATA                 (TCP_RX_DATA           ),
        .TX_FULL                 (TCP_TX_FULL           ),
        .TX_FILL                 (                      ),
        .TX_WR                   (TCP_TX_WR             ),
        .TX_DATA                 (TCP_TX_DATA           ),
        .LOC_ACT                 (RBCP_ACT              ),
        .LOC_ADDR                (RBCP_ADDR             ),
        .LOC_WD                  (RBCP_WD               ),
        .LOC_WE                  (RBCP_WE               ),
        .LOC_RE                  (RBCP_RE               ),
        .LOC_ACK                 (RBCP_ACK              ),
        .LOC_RD                  (RBCP_RD               )
    );

endmodule
