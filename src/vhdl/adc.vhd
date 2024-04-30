-----------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 2015/04/08 13:26:59
-- Design Name: 
-- Module Name: adc - Behavioral
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
use IEEE.numeric_std.all;


-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
library UNISIM;
use UNISIM.VComponents.all;

library work;
use work.rhea_pkg.all;

entity adc is
  port (
    clk    : in  std_logic;
    rst    : in  std_logic;
    -- RBCP I/F
    rbcp_we   : in  std_logic;
    rbcp_re   : in  std_logic;
    rbcp_ack  : out std_logic;
    rbcp_addr : in  std_logic_vector(31 downto 0);
    rbcp_wd   : in  std_logic_vector( 7 downto 0);
    rbcp_rd   : out std_logic_vector( 7 downto 0);
    -- ADC I/O
    cha_p  : in  adc_data_half;
    cha_n  : in  adc_data_half;
    chb_p  : in  adc_data_half;
    chb_n  : in  adc_data_half;
    dout_a : out adc_data;
    dout_b : out adc_data);
end adc;

architecture Behavioral of adc is

  signal addr_num : integer;

  signal a_ddr      : adc_data_half;
  signal b_ddr      : adc_data_half;
  signal a_ddr_dly  : adc_data_half;
  signal b_ddr_dly  : adc_data_half;
  signal dout_a_buf : adc_data;
  signal dout_b_buf : adc_data;
  signal swap_en    : std_logic;
  signal rst_buf_a  : adc_data_half;
  signal rst_buf_b  : adc_data_half;

  type delay_array is array (0 to  ADC_DATA_WIDTH/2-1) of std_logic_vector(8 downto 0);
  signal delay_array_a_in  : delay_array;
  signal delay_array_b_in  : delay_array;
  signal delay_array_a_out  : delay_array;
  signal delay_array_b_out  : delay_array;

  signal a_load     : std_logic_vector(ADC_DATA_WIDTH/2-1 downto 0);
  signal a_load_buf : std_logic_vector(ADC_DATA_WIDTH/2-1 downto 0);
  signal b_load     : std_logic_vector(ADC_DATA_WIDTH/2-1 downto 0);
  signal b_load_buf : std_logic_vector(ADC_DATA_WIDTH/2-1 downto 0);

begin

  ADC_Swap : process(clk)
  begin
    if rising_edge(clk) then
      if swap_en = '0' then
        dout_a <= dout_a_buf;
        dout_b <= dout_b_buf;
      else
        dout_a <= dout_b_buf;
        dout_b <= dout_a_buf;
      end if;
    end if;
  end process;

  ADC_Data : for i in 0 to ADC_DATA_WIDTH/2-1 generate

    Reset_FanOut_a : process(clk)
    begin
      if rising_edge(clk) then
        rst_buf_a(i) <= rst;
      end if;
    end process;

    Reset_FanOut_b : process(clk)
    begin
      if rising_edge(clk) then
        rst_buf_b(i) <= rst;
      end if;
    end process;

    Channel_A_IBUFDS_inst : IBUFDS
      generic map (
        DIFF_TERM    => false,
        IBUF_LOW_PWR => true,
        IOSTANDARD   => "lvds_25")
      port map (
        O  => a_ddr(i),
        I  => cha_p(i),
        IB => cha_n(i));

    Channel_B_IBUFDS_inst : IBUFDS
      generic map (
        DIFF_TERM    => false,
        IBUF_LOW_PWR => true,
        IOSTANDARD   => "lvds_25")
      port map (
        O  => b_ddr(i),
        I  => chb_p(i),
        IB => chb_n(i));

    -- mod 2022-03-09
    Channel_A_IDELAYE3_inst : IDELAYE3
      generic map (
        CASCADE          => "NONE",
        DELAY_FORMAT     => "COUNT",
        DELAY_SRC        => "IDATAIN",
        DELAY_TYPE       => "VAR_LOAD",
        DELAY_VALUE      => 0,
        IS_CLK_INVERTED  => '0',
        IS_RST_INVERTED  => '0',
        REFCLK_FREQUENCY => 300.0,
        SIM_DEVICE       => "ULTRASCALE",
        UPDATE_MODE      => "ASYNC"
)
      port map (
        CASC_OUT => open,
        CNTVALUEOUT => delay_array_a_out(i),
        DATAOUT => a_ddr_dly(i),
        CASC_IN => '0',
        CASC_RETURN => '0',
        CE => '0',
        CLK => clk,
        CNTVALUEIN => delay_array_a_in(i),
        DATAIN => '0',
        EN_VTC => '0',
        IDATAIN => a_ddr(i),
        INC => '0',
        LOAD => a_load_buf(i),
        RST => rst
     );

    Channel_B_IDELAYE3_inst : IDELAYE3
      generic map (
        CASCADE          => "NONE",
        DELAY_FORMAT     => "COUNT",
        DELAY_SRC        => "IDATAIN",
        DELAY_TYPE       => "VAR_LOAD",
        DELAY_VALUE      => 0,
        IS_CLK_INVERTED  => '0',
        IS_RST_INVERTED  => '0',
        REFCLK_FREQUENCY => 300.0,
        SIM_DEVICE       => "ULTRASCALE",
        UPDATE_MODE      => "ASYNC")
      port map (
        CASC_OUT => open,
        CNTVALUEOUT => delay_array_b_out(i),
        DATAOUT => b_ddr_dly(i),
        CASC_IN => '0',
        CASC_RETURN => '0',
        CE => '0',
        CLK => clk,
        CNTVALUEIN => delay_array_b_in(i),
        DATAIN => '0',
        EN_VTC => '0',
        IDATAIN => b_ddr(i),
        INC => '0',
        LOAD => b_load_buf(i),
        RST => rst
     );

    Channel_A_IDDR_inst : IDDRE1
      generic map (
        DDR_CLK_EDGE => "SAME_EDGE_PIPELINED")
      port map (
        Q1 => dout_a_buf(2*i),
        Q2 => dout_a_buf(2*i+1),
        C  => clk,
        CB => not clk,
        D  => a_ddr_dly(i),
        R  => rst_buf_a(i));

    Channel_B_IDDR_inst : IDDRE1
      generic map (
        DDR_CLK_EDGE => "SAME_EDGE_PIPELINED")
      port map (
        Q1 => dout_b_buf(2*i),
        Q2 => dout_b_buf(2*i+1),
        C  => clk,
        CB => not clk,
        D  => b_ddr_dly(i),
        R  => rst_buf_b(i));

  end generate ADC_Data;

  addr_num <= to_integer(unsigned(rbcp_addr(7 downto 0)));

  -- load buffering
   
  load_buf : for i in 0 to ADC_DATA_WIDTH/2-1 generate 
    process (rbcp_addr, rbcp_we, addr_num) begin
      if (addr_num = i) and (rbcp_addr(15 downto 8) = x"02") and (rbcp_we = '1') then -- ch A
        a_load(i) <= '1';
        b_load(i) <= '0';
      elsif (addr_num = i) and (rbcp_addr(15 downto 8) = x"04") and (rbcp_we = '1') then -- ch B
        a_load(i) <= '0';
        b_load(i) <= '1';
      else
        a_load(i) <= '0';
        b_load(i) <= '0';
      end if;
    end process;
  end generate load_buf;
  
  process(clk) begin
    if rising_edge(clk) then
      a_load_buf(ADC_DATA_WIDTH/2-1 downto 0) <= a_load(ADC_DATA_WIDTH/2-1 downto 0);
      b_load_buf(ADC_DATA_WIDTH/2-1 downto 0) <= b_load(ADC_DATA_WIDTH/2-1 downto 0);
    end if;
  end process;

  ADC_rbcp_proc : process(clk)
  begin
    if rising_edge(clk) then
      rbcp_ack <= '0';
      rbcp_rd  <= (others => '0');
      if rst = '1' then
        swap_en <= '0';  -- 0x1200_0000
      else

        -- control
        if rbcp_addr(31 downto 16) = x"1200" then
          if rbcp_addr(15 downto 0) = x"0000" then -- swap_en
            if rbcp_we = '1' then
              rbcp_ack <= '1';
              swap_en <= rbcp_wd(0);
            elsif rbcp_re = '1' then
              rbcp_ack <= '1';
              rbcp_rd(0) <= swap_en;
            end if;
          elsif rbcp_addr(15 downto 8) = x"01" then -- Port A LSB
            if rbcp_we = '1' then
              rbcp_ack <= '1';
              delay_array_a_in(addr_num) <= rbcp_wd(7 downto 0);
            elsif rbcp_re = '1' then
              rbcp_ack <= '1';
              rbcp_rd(7 downto 0) <= delay_array_a_out(addr_num)(7 downto 0);
            end if;
          elsif rbcp_addr(15 downto 8) = x"02" then -- Port A MSB
            if rbcp_we = '1' then
              rbcp_ack <= '1';
              delay_array_a_in(addr_num)(8) <= rbcp_wd(0);
            elsif rbcp_re = '1' then
              rbcp_ack <= '1';
              rbcp_rd(0) <= delay_array_a_out(addr_num)(8);
            end if;
          elsif rbcp_addr(15 downto 8) = x"03" then -- Port B MSB
            if rbcp_we = '1' then
              rbcp_ack <= '1';
              delay_array_b_in(addr_num)(7 downto 0) <= rbcp_wd(7 downto 0);
            elsif rbcp_re = '1' then
              rbcp_ack <= '1';
              rbcp_rd(7 downto 0) <= delay_array_b_out(addr_num)(7 downto 0);
            end if;
          elsif rbcp_addr(15 downto 8) = x"04" then -- Port B MSB
            if rbcp_we = '1' then
              rbcp_ack <= '1';
              delay_array_b_in(addr_num)(8) <= rbcp_wd(0);
            elsif rbcp_re = '1' then
              rbcp_ack <= '1';
              rbcp_rd(0) <= delay_array_b_out(addr_num)(8);
            end if;
          end if; 
        end if;

      end if;
    end if;
  end process;


end Behavioral;
