----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 2018/03/29 12:03:35
-- Design Name: 
-- Module Name: dds_scaled - Behavioral
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
----------------------------------------------------------------------------------


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

entity dds is
  port (
    clk   : in  std_logic;
    rst   : in  std_logic;
    en    : in  std_logic;
    sync  : in  std_logic;
    pinc  : in  phase_data; -- every       1 clock
    poff  : in  phase_data;
    cos   : out dds_data;
    sin   : out dds_data;
    phase : out phase_data);
end entity dds;

architecture Behavioral of dds is

  constant DDS_INPUT_WIDTH : integer := 32;
  -- DDS_INPUT_WIDTH is smallest multiple of 8 which larger than PHASE_WIDTH.
  -- width of s_axis_phase_tdata = 2*DDS_INPUT_WIDTH + 8.
 
--  component dds_compiler_0 is -- 20bits
  component dds_compiler is -- 32bits
    port (
      aclk                : in  std_logic;
      s_axis_phase_tvalid : in  std_logic;
      s_axis_phase_tdata  : in  std_logic_vector(DDS_INPUT_WIDTH*2+7 downto 0);
      m_axis_data_tvalid  : out std_logic;
      m_axis_data_tdata   : out std_logic_vector(SIN_COS_WIDTH*2-1 downto 0);
      m_axis_phase_tvalid : out std_logic;
      m_axis_phase_tdata  : out std_logic_vector(DDS_INPUT_WIDTH-1 downto 0));
  end component dds_compiler;
--  end component dds_compiler_0;

  component c_addsub_0 is
    port(
      clk : in  std_logic;
      a   : in  phase_data;
      b   : in  phase_data;
      s   : out phase_data);
  end component c_addsub_0;

  signal sync_in   : std_logic;
  signal pinc_in   : phase_data;
  signal poff_in   : phase_data;
  signal dds_in    : std_logic_vector(DDS_INPUT_WIDTH*2 +7 downto 0);
  signal dds_out   : std_logic_vector(SIN_COS_WIDTH*2 -1 downto 0);
  signal phase_out : std_logic_vector(DDS_INPUT_WIDTH -1 downto 0);
  
begin

  pinc_in_buff : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        pinc_in <= (others => '0');
      else
        if en = '1' then
          pinc_in <= pinc;
        end if;
      end if;
    end if;
  end process;

  poff_in_buff : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        poff_in <= (others => '0');
      else
        if en = '1' then
          poff_in <= poff;
        end if;
      end if;
    end if;
  end process;

  sync_buff : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        sync_in <= '1';
      else
        sync_in <= en or sync;
      end if;
    end if;
  end process;

  dds_in(DDS_INPUT_WIDTH*2 +7 downto DDS_INPUT_WIDTH*2 +1) <= (others => '0');
  dds_in(DDS_INPUT_WIDTH*2                               ) <= sync_in;
  dds_in(DDS_INPUT_WIDTH*2 -1 downto DDS_INPUT_WIDTH + PHASE_WIDTH ) <= (others => '0');
  dds_in(DDS_INPUT_WIDTH + PHASE_WIDTH -1 downto DDS_INPUT_WIDTH ) <= poff_in;
  dds_in(DDS_INPUT_WIDTH  -1              downto PHASE_WIDTH     ) <= (others => '0');
  dds_in(PHASE_WIDTH  -1                  downto 0              ) <= pinc_in;

  DDS_Compiler_inst : dds_compiler
    port map (
      aclk                => clk,
      s_axis_phase_tvalid => '1',
      s_axis_phase_tdata  => dds_in,
      m_axis_data_tvalid  => open,
      m_axis_data_tdata   => dds_out,
      m_axis_phase_tvalid => open,
      m_axis_phase_tdata  => phase_out);


  sin_out_buff : process(clk)
  begin
    if rising_edge(clk) then
      sin <= dds_out(SIN_COS_WIDTH*2-1 downto SIN_COS_WIDTH);
    end if;
  end process;

  cos_out_buff : process(clk)
  begin
    if rising_edge(clk) then
      cos <= dds_out(SIN_COS_WIDTH  -1 downto 0);
    end if;
  end process;

  phase_out_buff : process(clk)
  begin
    if rising_edge(clk) then
      phase <= phase_out(PHASE_WIDTH -1 downto 0);
    end if;
  end process;

end architecture Behavioral;


