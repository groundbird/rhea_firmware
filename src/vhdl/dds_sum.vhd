-----------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 2015/09/30 23:04:02
-- Design Name: 
-- Module Name: dds_sum - Behavioral
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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

library work;
use work.rhea_pkg.all;

entity dds_sum is
  port (
    clk     : in  std_logic;
    rst     : in  std_logic;
    dds_in  : in  dds_data_array;
    amps    : in  amp_array;
    en      : in  std_logic;
    dac_out : out dds_data);
end dds_sum;

architecture Behavioral of dds_sum is

  constant ADDER_WIDTH : integer := SIN_COS_WIDTH + N_SUMUP_OFFSET;
  subtype adder_data_type  is std_logic_vector(ADDER_WIDTH-1 downto 0);
  type adder_data_input is array (N_CHANNEL-1 downto 0) of adder_data_type;
  type adder_data_array is array (2**(N_CHANNEL_LOG2+1)-2 downto 0) of adder_data_type;
  -- (0) <= (1, 2) <= (3, 4, 5, 6) <= (7, 8, 9, 10) <= ... <= (2**N-1, 2**(N+1)-2)

  component dds_adder is
    port (
      clk : in  std_logic;
      a   : in  adder_data_type;
      b   : in  adder_data_type;
      s   : out adder_data_type);
  end component dds_adder;

  component Mult_for_DDSamp is
    port (
      clk       : in  std_logic;
      A         : in  dds_data;
      B         : in  amp_data;
      P         : out dds_data);
  end component Mult_for_DDSamp;

  signal dds_in_buf   : adder_data_input;
  signal dds_data_in  : adder_data_array;
  signal dds_data_out : adder_data_array;
  signal amps_in      : amp_array;
  signal dds_in_amped : dds_data_array;

begin

  amps_in_buff : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        amps_in <= (others => (others => '0'));
      else
        if en = '1' then
          amps_in <= amps;
        end if;
      end if;
    end if;
  end process;

  Amplitude_tune  : for i in 0 to N_CHANNEL-1 generate
    DDS_amp_inst : Mult_for_DDSamp
      port map (
        CLK       => clk,
        A         => dds_in(i),
        B         => amps_in(i),
        P         => dds_in_amped(i) );
  end generate;
    
  input_buffer1  : for i in 0 to N_CHANNEL-1 generate
    process(clk)
    begin
      if rising_edge(clk) then
        dds_in_buf(i)(ADDER_WIDTH-1 downto N_SUMUP_OFFSET) <= dds_in_amped(i);
--        dds_in_buf(i)(ADDER_WIDTH-1 downto N_SUMUP_OFFSET) <= dds_in(i);
        dds_in_buf(i)(N_SUMUP_OFFSET-1 downto 0) <= (others => '0');
      end if;
    end process;
  end generate;

  input_buffer2 : for i in 0 to N_CHANNEL-1 generate
    process(clk)
    begin
      if rising_edge(clk) then
        dds_data_out(2**N_CHANNEL_LOG2-1 + i) <= dds_in_buf(i);
      end if;
    end process;
  end generate;

  output_to_input_divede_2 : for i in 0 to 2**(N_CHANNEL_LOG2+1)-2 generate
    process(clk)
    begin
      if rising_edge(clk) then
        dds_data_in(i)(ADDER_WIDTH-1) <= dds_data_out(i)(ADDER_WIDTH-1);
        dds_data_in(i)(ADDER_WIDTH-2 downto 0) <= dds_data_out(i)(ADDER_WIDTH-1 downto 1);
      end if;
    end process;
  end generate;

  add_inst_gen : for i in 0 to N_CHANNEL_LOG2-1 generate
    add_inst_gen2 : for j in 0 to 2**i-1 generate
      dds_adder_inst : dds_adder
        port map(
          clk => clk,
          a   => dds_data_in (2**(i+1)-1 + 2*j),
          b   => dds_data_in (2**(i+1)-1 + 2*j + 1),
          s   => dds_data_out(2**i-1 + j));
    end generate;
  end generate;

  output_buffer : process(clk)
  begin
    if rising_edge(clk) then
      dac_out <= dds_data_out(0)(ADDER_WIDTH-1 downto N_SUMUP_OFFSET);
    end if;
  end process;

end architecture Behavioral;
