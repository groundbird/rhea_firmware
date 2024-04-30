------------------------------------------------------------------------------- Company: 
-- Engineer: 
-- 
-- Create Date: 2015/06/23 12:22:36
-- Design Name: 
-- Module Name: downsampler - Behavioral
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
use IEEE.MATH_REAL.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

library work;
use work.rhea_pkg.all;

entity downsampler is
  port (
    clk     : in  std_logic;
    rst     : in  std_logic;
    sync_in : in  std_logic;
    cnt_out : out std_logic_vector(IQ_DS_DATA_WIDTH-1 downto 0);
    ack     : out std_logic;
    rate    : in  integer range DS_RATE_MIN to DS_RATE_MAX;
    din     : in  std_logic_vector(IQ_DATA_WIDTH-1 downto 0);
    dout    : out std_logic_vector(IQ_DS_DATA_WIDTH-1 downto 0);
    valid   : out std_logic);
end entity downsampler;

architecture Behavioral of downsampler is

  constant LATENCY_SUB : integer := 8;   -- subtracter latency (< DS_RATE_MIN)

  component accumulator is
    port (
      clk  : in  std_logic;
      sclr : in  std_logic;
      b    : in  std_logic_vector(IQ_DATA_WIDTH-1 downto 0);
      q    : out std_logic_vector(IQ_DS_DATA_WIDTH-1 downto 0));
  end component accumulator;

  component ds_subtracter is
    port (
      clk : in  std_logic;
      a   : in  std_logic_vector(IQ_DS_DATA_WIDTH-1 downto 0);
      b   : in  std_logic_vector(IQ_DS_DATA_WIDTH-1 downto 0);
      s   : out std_logic_vector(IQ_DS_DATA_WIDTH-1 downto 0));
  end component  ds_subtracter;

  signal din_buf : std_logic_vector(IQ_DATA_WIDTH-1 downto 0);
  signal d_acc   : std_logic_vector(IQ_DS_DATA_WIDTH-1 downto 0);
  signal d_prev  : std_logic_vector(IQ_DS_DATA_WIDTH-1 downto 0);
  signal d_curr  : std_logic_vector(IQ_DS_DATA_WIDTH-1 downto 0);

  signal counter     : integer range 0 to DS_RATE_MAX-1;
  signal latency_cnt : integer range 0 to LATENCY_SUB;
  signal cnt_en      : std_logic;

  constant COUNTER_WIDTH : integer := integer(log2(real(DS_RATE_MAX-1)));
  signal cnt_buf         : std_logic_vector(COUNTER_WIDTH - 1 downto 0);
  signal cnt_zeros       : std_logic_vector(IQ_DS_DATA_WIDTH - COUNTER_WIDTH - 1 downto 0);

  signal dout_buf  : std_logic_vector(IQ_DS_DATA_WIDTH-1 downto 0);
  signal valid_buf : std_logic;

begin

  Accumulator_inst : accumulator
    port map (
      clk  => clk,
      sclr => rst,
      b    => din_buf,
      q    => d_acc);

  DS_Subtracter_inst : ds_subtracter
    port map (
      clk => clk,
      a   => d_curr,
      b   => d_prev,
      s   => dout_buf);

  process(clk)
  begin
    if rising_edge(clk) then
      din_buf <= din;
    end if;
  end process;

  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        counter <= 0;
      else
        if counter >= rate-1 then
          counter <= 0;
        else
          counter <= counter + 1;
        end if;
      end if;
    end if;
  end process;

  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        d_prev <= (others => '0');
        d_curr <= (others => '0');
      else
        if counter = 0 then
          d_prev <= d_curr;
          d_curr <= d_acc;
        end if;
      end if;
    end if;
  end process;

  valid_buf <= '1' when counter = LATENCY_SUB else '0';

  Output_Buffer : process(clk)
  begin
    if rising_edge(clk) then
      dout  <= dout_buf;
      valid <= valid_buf;
    end if;
  end process;

  -- counter data to formatter
  Count_to_Formatter : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        cnt_out <= (others => '0');
      else
        if sync_in = '1' then
            cnt_out <= cnt_zeros & cnt_buf;
          end if;
      end if;
    end if;
  end process;
  cnt_buf   <= conv_std_logic_vector(counter,COUNTER_WIDTH);
  cnt_zeros <= (others => '0');
  
  Ack_to_Synchronizer : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        ack <= '0';
      else
        if latency_cnt = LATENCY_SUB-1 then
          ack <= '1';
        else
          ack <= '0';
        end if;
      end if;
    end if;
  end process;
  
  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        cnt_en <= '0';
      else
        if sync_in = '1' then
            cnt_en <= '1';
        else if latency_cnt = LATENCY_SUB-2 then
               cnt_en <= '0';
             end if;
        end if;
      end if;
    end if;
  end process;
  
  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        latency_cnt <= 0;
      else
        if cnt_en = '1' then
          latency_cnt <= latency_cnt + 1;
        else
          latency_cnt <= 0;
        end if;
      end if;
    end if;
  end process;
  
end architecture Behavioral;
