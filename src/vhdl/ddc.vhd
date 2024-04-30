-----------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 2015/06/11 13:16:18
-- Design Name: 
-- Module Name: ddc - Behavioral
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

entity ddc is
  port (
    clk    : in  std_logic;
    adcd_a : in  adc_data;
    adcd_b : in  adc_data;
    cos    : in  dds_data;
    sin    : in  dds_data;
    iout   : out iq_data;
    qout   : out iq_data);
end entity ddc;

architecture Behavioral of ddc is

  component multiplier is
    port (
      clk : in  std_logic;
      a   : in  adc_data;
      b   : in  dds_data;
      p   : out iq_data_half);
  end component multiplier;

  signal adcd_a_buf : adc_data;
  signal adcd_b_buf : adc_data;
  signal adcd_a_buf2: adc_data;
  signal adcd_b_buf2: adc_data;
  signal cos_buf    : dds_data;
  signal sin_buf    : dds_data;
  signal cos_buf2   : dds_data;
  signal sin_buf2   : dds_data;

  signal coscos : iq_data_half;
  signal sinsin : iq_data_half;
  signal sincos : iq_data_half;
  signal cossin : iq_data_half;

  signal coscos_buf : iq_data_half;
  signal sinsin_buf : iq_data_half;
  signal sincos_buf : iq_data_half;
  signal cossin_buf : iq_data_half;

  component adder is
    port (
      a   : in  iq_data_half;
      b   : in  iq_data_half;
      clk : in  std_logic;
      s   : out iq_data);
  end component adder;

  signal iout_buf : iq_data;

  component subtracter is
    port (
      a   : in  iq_data_half;
      b   : in  iq_data_half;
      clk : in  std_logic;
      s   : out iq_data);
  end component subtracter;

  signal qout_buf : iq_data;

begin

  process(clk)
  begin
    if rising_edge(clk) then
      adcd_a_buf2 <= adcd_a;
      adcd_b_buf2 <= adcd_b;
    end if;
  end process;

  process(clk)
  begin
    if rising_edge(clk) then
      adcd_a_buf <= adcd_a_buf2;
      adcd_b_buf <= adcd_b_buf2;
    end if;
  end process;

  process(clk)
  begin
    if rising_edge(clk) then
      cos_buf2 <= cos;
      sin_buf2 <= sin;
    end if;
  end process;

  process(clk)
  begin
    if rising_edge(clk) then
      cos_buf  <= cos_buf2;
      sin_buf  <= sin_buf2;
    end if;
  end process;

  process(clk)
  begin
    if rising_edge(clk) then
      coscos_buf <= coscos;
      sinsin_buf <= sinsin;
      sincos_buf <= sincos;
      cossin_buf <= cossin;
    end if;
  end process;

  process(clk)
  begin
    if rising_edge(clk) then
      iout       <= iout_buf;
      qout       <= qout_buf;
    end if;
  end process;

  ---------------------------------------------------------------------------
  -- Multiplier
  ---------------------------------------------------------------------------
  CosCos_Multiplier_inst : multiplier
    port map (
      clk => clk,
      a   => adcd_a_buf,
      b   => cos_buf,
      p   => coscos);

  SinSin_Multiplier_inst : multiplier
    port map (
      clk => clk,
      a   => adcd_b_buf,
      b   => sin_buf,
      p   => sinsin);

  CosSin_Multiplier_inst : multiplier
    port map (
      clk => clk,
      a   => adcd_a_buf,
      b   => sin_buf,
      p   => cossin);

  SinCos_Multiplier_inst : multiplier
    port map (
      clk => clk,
      a   => adcd_b_buf,
      b   => cos_buf,
      p   => sincos);

  ---------------------------------------------------------------------------
  -- Adder/Substracter
  ---------------------------------------------------------------------------
  CosCos_SinSin_Adder_inst : adder
    port map (
      a   => coscos_buf,
      b   => sinsin_buf,
      clk => clk,
      s   => iout_buf);

  SinCos_CosSin_Substracter_inst : subtracter
    port map (
      a   => sincos_buf,
      b   => cossin_buf,
      clk => clk,
      s   => qout_buf);

end architecture Behavioral;
