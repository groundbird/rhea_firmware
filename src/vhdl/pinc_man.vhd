-----------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 2016/05/23
-- Design Name: 
-- Module Name: pinc_man - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
-----------------------------------------------------------------------------


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

entity pinc_man is
  port (
    clk  : in  std_logic;
    rst  : in  std_logic;
    -- RBCP I/F
    rbcp_we   : in  std_logic;
    rbcp_re   : in  std_logic;
    rbcp_ack  : out std_logic;
    rbcp_addr : in  std_logic_vector(31 downto 0);
    rbcp_wd   : in  std_logic_vector( 7 downto 0);
    rbcp_rd   : out std_logic_vector( 7 downto 0);
    -- P_INC OUT
    dds_en : out std_logic;
    sync   : out std_logic;
    amps   : out amp_array;
    pinc   : out phase_array;
    poff   : out phase_array);
end pinc_man;

architecture Behavioral of pinc_man is

  subtype buf_4byte_subtype is std_logic_vector(31 downto 0);
  type buf_4byte_type is array (N_CHANNEL-1 downto 0) of buf_4byte_subtype;
  --subtype buf_2byte_subtype is std_logic_vector(15 downto 0);
  --type buf_2byte_type is array (N_CHANNEL-1 downto 0) of buf_2byte_subtype;
  signal pinc_buf  : buf_4byte_type;    -- PHASE_WIDTH
  signal poff_buf  : buf_4byte_type;    -- PHASE_WIDTH
  signal amps_buf  : buf_4byte_type;    -- 
  signal cycle_buf : buf_4byte_subtype; -- (0 -- DS_RATE_MAX-1)

  signal sync_flg : std_logic;
  signal sync_trg : std_logic;
  signal sync_cnt : integer range 0 to DS_RATE_MAX-1;
  signal sync_cyc : integer range 0 to DS_RATE_MAX;

  signal int_ch   : integer range 0 to 255;
  signal int_type : integer range 0 to  15;
  signal int_byte : integer range 0 to  15;

  signal rbcp_buf_we   : std_logic;
  signal rbcp_buf_re   : std_logic;
  signal rbcp_buf_ack  : std_logic;
  signal rbcp_buf_addr : std_logic_vector(31 downto 0);
  signal rbcp_buf_wd   : std_logic_vector( 7 downto 0);
  signal rbcp_buf_rd   : std_logic_vector( 7 downto 0);

begin  -- architecture Behavioral

  rbcp_buff : process(clk)
  begin
    if rising_edge(clk) then
      rbcp_buf_we   <= rbcp_we;
      rbcp_buf_re   <= rbcp_re;
      rbcp_ack  <= rbcp_buf_ack;
      rbcp_buf_addr <= rbcp_addr;
      rbcp_buf_wd   <= rbcp_wd;
      rbcp_rd   <= rbcp_buf_rd;
    end if;
  end process;

  output_buff : for i in 0 to N_CHANNEL-1 generate
    process(clk)
    begin
      if rising_edge(clk) then
        amps(i) <= amps_buf(i)(7 downto 0);
        pinc(i) <= pinc_buf(i)(PHASE_WIDTH-1 downto 0);
        poff(i) <= poff_buf(i)(PHASE_WIDTH-1 downto 0);
      end if;
    end process;
  end generate output_buff;

  sync_cyc_setting : process(clk)
  begin
    if rising_edge(clk) then
      if conv_integer(cycle_buf) >= DS_RATE_MIN
        and conv_integer(cycle_buf) <= DS_RATE_MAX then
        sync_cyc <= conv_integer(cycle_buf);
      else
        sync_cyc <= DS_RATE_MAX;
      end if;
    end if;
  end process;

  sync_cnt_setting : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        sync_cnt <= 0;
      else
        if sync_trg = '1' or sync_cnt >= sync_cyc-1 then
          sync_cnt <= 0;
        else
          sync_cnt <= sync_cnt + 1;
        end if;
      end if;
    end if;
  end process;

  sync_setting : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        sync <= '0';
      else
        if sync_flg = '1' and sync_cnt = 0 then
          sync <= '1';
        else
          sync <= '0';
        end if;
      end if;
    end if;
  end process;

  int_ch   <= conv_integer(rbcp_buf_addr(15 downto 8));
  int_type <= conv_integer(rbcp_buf_addr( 7 downto 4));
  int_byte <= conv_integer(rbcp_buf_addr( 3 downto 0));

  rbcp_comm : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        rbcp_buf_ack <= '0';
        rbcp_buf_rd  <= (others => '0');
        dds_en   <= '0';
        sync_trg <= '0';
        sync_flg <= '0';
        pinc_buf <= (others => (others => '0'));
        poff_buf <= (others => (others => '0'));
        amps_buf <= (others => (others => '0'));
        cycle_buf<= (others => '0');
      else
        rbcp_buf_ack <= '0';
        rbcp_buf_rd  <= (others => '0');
        dds_en   <= '0';
        sync_trg <= '0';

        case rbcp_buf_addr(31 downto 16) is
          when x"4000" =>
            if rbcp_buf_addr(15 downto 0) = x"0000" then
              if rbcp_buf_we = '1' then
                rbcp_buf_ack <= '1';
                dds_en   <= rbcp_buf_wd(0);
                sync_trg <= '1';
              end if;

            elsif rbcp_buf_addr(15 downto 0) = x"0001" then
              if rbcp_buf_we = '1' then
                rbcp_buf_ack <= '1';
                sync_flg <= rbcp_buf_wd(0);
                sync_trg <= '1';
              elsif rbcp_buf_re = '1' then
                rbcp_buf_ack <= '1';
                rbcp_buf_rd(0) <= sync_flg;
              end if;

            end if;

          -- x"4100CCTB"
          --   CC: channel (0-N_CHANNEL)
          --    T: type(0: phase_increment(4byte), 1: phase_offset(4byte) 2: amplitude scale(4byte))
          --    B: byte_number
          when x"4100" =>
            if int_ch < N_CHANNEL then

              if int_type = 0 then  -- phase increment
                if int_byte < 4 then
                  if rbcp_buf_we = '1' then
                    rbcp_buf_ack <= '1';
                    pinc_buf(int_ch)((3-int_byte)*8 + 7 downto (3-int_byte)*8) <= rbcp_buf_wd;
                  elsif rbcp_buf_re = '1' then
                    rbcp_buf_ack <= '1';
                    rbcp_buf_rd <= pinc_buf(int_ch)((3-int_byte)*8 + 7 downto (3-int_byte)*8);
                  end if;
                end if;

              elsif int_type = 1 then  -- phase offset
                if int_byte < 4 then
                  if rbcp_buf_we = '1' then
                    rbcp_buf_ack <= '1';
                    poff_buf(int_ch)((3-int_byte)*8 + 7 downto (3-int_byte)*8) <= rbcp_buf_wd;
                  elsif rbcp_buf_re = '1' then
                    rbcp_buf_ack <= '1';
                    rbcp_buf_rd <= poff_buf(int_ch)((3-int_byte)*8 + 7 downto (3-int_byte)*8);
                  end if;
                end if;
              
              elsif int_type = 2 then
                if int_byte < 4 then
                  if rbcp_buf_we = '1' then
                    rbcp_buf_ack <= '1';
                    amps_buf(int_ch)((3-int_byte)*8 + 7 downto (3-int_byte)*8) <= rbcp_buf_wd;
                  elsif rbcp_buf_re = '1' then
                    rbcp_buf_ack <= '1';
                    rbcp_buf_rd <= amps_buf(int_ch)((3-int_byte)*8 + 7 downto (3-int_byte)*8);
                  end if;
                end if;

              end if;
            end if;

          -- x"4101_000B",  B: byte_number(0-3)
          -- dds sync cycle
          when x"4101" =>
            if rbcp_buf_addr(15 downto 4) = x"000" then
              if int_byte < 4 then
                if rbcp_buf_we = '1' then
                  rbcp_buf_ack <= '1';
                  cycle_buf((3-int_byte)*8 + 7 downto (3-int_byte)*8) <= rbcp_buf_wd;
                elsif rbcp_buf_re = '1' then
                  rbcp_buf_ack <= '1';
                  rbcp_buf_rd  <= cycle_buf((3-int_byte)*8 + 7 downto (3-int_byte)*8);
                end if;
              end if;
            end if;

          when others => null;

        end case;
      end if;
    end if;
  end process;

end architecture Behavioral;
