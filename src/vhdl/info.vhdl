library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_ARITH.all;
use IEEE.STD_LOGIC_SIGNED.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

library work;
use work.rhea_pkg.all;

entity info is
  port (
    clk : in  std_logic;
    rst : in  std_logic;
    -- RBCP I/F
    rbcp_we   : in  std_logic;
    rbcp_re   : in  std_logic;
    rbcp_ack  : out std_logic;
    rbcp_addr : in  std_logic_vector(31 downto 0);
    rbcp_wd   : in  std_logic_vector( 7 downto 0);
    rbcp_rd   : out std_logic_vector( 7 downto 0);
    eeprom_dbg_addr   : out std_logic_vector(6 downto 0);
    eeprom_dbg_data   : in  std_logic_vector(7 downto 0);
    eeprom_dbg_status : in  std_logic_vector(7 downto 0);
    -- Network parameters as loaded by SiTCP
    sitcp_mac         : in  std_logic_vector(47 downto 0);
    sitcp_ip          : in  std_logic_vector(31 downto 0);
    sitcp_tcp_port    : in  std_logic_vector(15 downto 0);
    sitcp_rbcp_port   : in  std_logic_vector(15 downto 0);
    sitcp_rst_count   : in  std_logic_vector(7 downto 0);
    -- EEPROM maintenance
    eeprom_wr_req     : out std_logic;
    eeprom_wr_addr    : out std_logic_vector(6 downto 0);
    eeprom_wr_data    : out std_logic_vector(7 downto 0);
    eeprom_reload_req : out std_logic);
end info;

architecture Behavioral of info is

  signal rbcp_we_buf   : std_logic;
  signal rbcp_re_buf   : std_logic;
  signal rbcp_ack_buf  : std_logic;
  signal rbcp_addr_buf : std_logic_vector(31 downto 0);
  signal rbcp_wd_buf   : std_logic_vector( 7 downto 0);
  signal rbcp_rd_buf   : std_logic_vector( 7 downto 0);

  ---------------------------------------------------------------------------
  -- SiTCP EEPROM maintenance registers (base 0x0000_0200)
  --
  -- These stay reachable whenever RBCP itself works, which includes the
  -- force-default mode used to recover a board whose EEPROM parameter block
  -- is wrong.  Writing the EEPROM through SiTCP's own 0xFFFF_FCxx space is
  -- not possible in that situation, because SiTCP never accepts the image.
  --
  --   0x200 R   bridge status (same bits as 0x100)
  --   0x201 R   SiTCP self-reset count (climbing = SiTCP rejects the image)
  --   0x202 R   MAC address, 6 bytes, most significant byte first
  --   0x208 R   IP address, 4 bytes
  --   0x20C R   TCP main port, 2 bytes
  --   0x20E R   RBCP port, 2 bytes
  --   0x210 R/W byte to write into the EEPROM shadow
  --   0x211 R/W EEPROM address to write (0-127)
  --   0x212 W   write 0xA5 to queue the byte at 0x211 into the 24LC04
  --   0x213 W   write 0x5A to re-read the 24LC04 and restart SiTCP
  ---------------------------------------------------------------------------
  constant EEPROM_WR_KEY     : std_logic_vector(7 downto 0) := x"A5";
  constant EEPROM_RELOAD_KEY : std_logic_vector(7 downto 0) := x"5A";

  signal wr_data_reg   : std_logic_vector(7 downto 0) := (others => '0');
  signal wr_addr_reg   : std_logic_vector(6 downto 0) := (others => '0');
  signal wr_req_reg    : std_logic := '0';
  signal reload_reg    : std_logic := '0';
  signal param_bytes   : std_logic_vector(7 downto 0);

  signal byte_num : integer range 0 to 3;
  signal version_buf : std_logic_vector(31 downto 0)
    := conv_std_logic_vector(RHEA_VERSIONS, 32);
  signal channel_buf : std_logic_vector( 7 downto 0)
    := conv_std_logic_vector(N_CHANNEL, 8);
  signal en_snap_buf : std_logic_vector( 7 downto 0)
    := conv_std_logic_vector(ENABLE_SNAPSHOT, 8);
  signal ch_trig_buf : std_logic_vector( 7 downto 0)
    := conv_std_logic_vector(N_CH_TRIG, 8);

begin

  eeprom_dbg_addr   <= rbcp_addr_buf(6 downto 0);
  eeprom_wr_req     <= wr_req_reg;
  eeprom_wr_addr    <= wr_addr_reg;
  eeprom_wr_data    <= wr_data_reg;
  eeprom_reload_req <= reload_reg;

  -- 0x200-0x20F read multiplexer.  The selector stays a std_logic_vector on
  -- purpose: STD_LOGIC_SIGNED is in scope here, so conv_integer would read
  -- 0x8-0xF as negative values.
  with rbcp_addr_buf(3 downto 0) select param_bytes <=
    eeprom_dbg_status            when x"0",
    sitcp_rst_count              when x"1",
    sitcp_mac(47 downto 40)      when x"2",
    sitcp_mac(39 downto 32)      when x"3",
    sitcp_mac(31 downto 24)      when x"4",
    sitcp_mac(23 downto 16)      when x"5",
    sitcp_mac(15 downto  8)      when x"6",
    sitcp_mac( 7 downto  0)      when x"7",
    sitcp_ip (31 downto 24)      when x"8",
    sitcp_ip (23 downto 16)      when x"9",
    sitcp_ip (15 downto  8)      when x"A",
    sitcp_ip ( 7 downto  0)      when x"B",
    sitcp_tcp_port (15 downto 8) when x"C",
    sitcp_tcp_port ( 7 downto 0) when x"D",
    sitcp_rbcp_port(15 downto 8) when x"E",
    sitcp_rbcp_port( 7 downto 0) when x"F",
    (others => '0')              when others;

  rbcp_buffering : process(clk)
  begin
    if rising_edge(clk) then
      rbcp_we_buf   <= rbcp_we;
      rbcp_re_buf   <= rbcp_re;
      rbcp_addr_buf <= rbcp_addr;
      rbcp_wd_buf   <= rbcp_wd;
      rbcp_ack      <= rbcp_ack_buf;
      rbcp_rd       <= rbcp_rd_buf;
    end if;
  end process;

  byte_num <= conv_integer(rbcp_addr_buf);

  rbcp_proc : process(clk)
  begin
    if rising_edge(clk) then
      rbcp_ack_buf <= '0';
      rbcp_rd_buf  <= (others => '0');

      if rbcp_addr_buf(31 downto 4) = x"0000" & x"000" then
        if byte_num >= 0 and byte_num < 4 then
          if rbcp_re_buf = '1' then
            rbcp_ack_buf <= '1';
            rbcp_rd_buf  <= version_buf(8*(3-byte_num) + 7 downto 8*(3-byte_num));
          end if;
        end if;
      end if;

      if rbcp_addr_buf(31 downto 0) = x"0000" & x"0010" then
        if rbcp_re_buf = '1' then
          rbcp_ack_buf <= '1';
          rbcp_rd_buf  <= channel_buf;
        end if;
      end if;

      if rbcp_addr_buf(31 downto 0) = x"0000" & x"0011" then
        if rbcp_re_buf = '1' then
          rbcp_ack_buf <= '1';
          rbcp_rd_buf  <= en_snap_buf;
        end if;
      end if;

      if rbcp_addr_buf(31 downto 0) = x"0000" & x"0012" then
        if rbcp_re_buf = '1' then
          rbcp_ack_buf <= '1';
          rbcp_rd_buf  <= ch_trig_buf;
        end if;
      end if;

      if rbcp_addr_buf(31 downto 8) = x"000001" then
        if rbcp_re_buf = '1' then
          if rbcp_addr_buf(7 downto 0) = x"00" then
            rbcp_ack_buf <= '1';
            rbcp_rd_buf  <= eeprom_dbg_status;
          elsif rbcp_addr_buf(7) = '1' then
            rbcp_ack_buf <= '1';
            rbcp_rd_buf  <= eeprom_dbg_data;
          end if;
        end if;
      end if;

      -- SiTCP parameter readback and EEPROM maintenance
      wr_req_reg <= '0';
      reload_reg <= '0';

      if rbcp_addr_buf(31 downto 8) = x"000002" then

        if rbcp_addr_buf(7 downto 4) = x"0" then
          if rbcp_re_buf = '1' then
            rbcp_ack_buf <= '1';
            rbcp_rd_buf  <= param_bytes;
          end if;
        end if;

        if rbcp_addr_buf(7 downto 0) = x"10" then
          if rbcp_re_buf = '1' then
            rbcp_ack_buf <= '1';
            rbcp_rd_buf  <= wr_data_reg;
          elsif rbcp_we_buf = '1' then
            rbcp_ack_buf <= '1';
            wr_data_reg  <= rbcp_wd_buf;
          end if;
        end if;

        if rbcp_addr_buf(7 downto 0) = x"11" then
          if rbcp_re_buf = '1' then
            rbcp_ack_buf <= '1';
            rbcp_rd_buf  <= '0' & wr_addr_reg;
          elsif rbcp_we_buf = '1' then
            rbcp_ack_buf <= '1';
            wr_addr_reg  <= rbcp_wd_buf(6 downto 0);
          end if;
        end if;

        -- Key-protected triggers, so a stray write cannot touch the EEPROM
        if rbcp_addr_buf(7 downto 0) = x"12" then
          if rbcp_we_buf = '1' then
            rbcp_ack_buf <= '1';
            if rbcp_wd_buf = EEPROM_WR_KEY then
              wr_req_reg <= '1';
            end if;
          elsif rbcp_re_buf = '1' then
            rbcp_ack_buf <= '1';
            rbcp_rd_buf  <= (others => '0');
          end if;
        end if;

        if rbcp_addr_buf(7 downto 0) = x"13" then
          if rbcp_we_buf = '1' then
            rbcp_ack_buf <= '1';
            if rbcp_wd_buf = EEPROM_RELOAD_KEY then
              reload_reg <= '1';
            end if;
          elsif rbcp_re_buf = '1' then
            rbcp_ack_buf <= '1';
            rbcp_rd_buf  <= (others => '0');
          end if;
        end if;

      end if;

    end if;
  end process;

end Behavioral;
