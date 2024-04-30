-----------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 2015/06/08 18:54:00
-- Design Name: 
-- Module Name: dac - Behavioral
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

library UNISIM;
use UNISIM.VComponents.all;

entity dac is
  port (
    clk      : in  std_logic;
    clk_2x   : in  std_logic;
    clk_2x2  : in  std_logic;
    rst      : in  std_logic;
    -- RBCP I/F
    rbcp_we   : in  std_logic;
    rbcp_re   : in  std_logic;
    rbcp_ack  : out std_logic;
    rbcp_addr : in  std_logic_vector(31 downto 0);
    rbcp_wd   : in  std_logic_vector( 7 downto 0);
    rbcp_rd   : out std_logic_vector( 7 downto 0);
    -- DAC I/O   
    din_a    : in  std_logic_vector(15 downto 0);
    din_b    : in  std_logic_vector(15 downto 0);
    dclk_p   : out std_logic;
    dclk_n   : out std_logic;
    frame_p  : out std_logic;
    frame_n  : out std_logic;
    frame_out: out std_logic; --debug
    dout_p   : out std_logic_vector(7 downto 0);
    dout_n   : out std_logic_vector(7 downto 0);
    txenable : out std_logic);
end entity dac;

architecture behavioral of dac is

  component dac_obuf is
    port(
      clk_div : in  std_logic;
      clk_2x  : in  std_logic;
      clk     : in  std_logic;
      rst     : in  std_logic;
      I       : in  std_logic_vector(3 downto 0);
      
      delay_count_out : out std_logic_vector(8 downto 0);
      delay_count_in  : in  std_logic_vector(8 downto 0);
      delay_load      : in  std_logic;

      O_p     : out std_logic;
      O_n     : out std_logic);
  end component dac_obuf;

  signal clk_div : std_logic;

  signal addr_num : integer;

  signal txenable_buf : std_logic;
  signal frame        : std_logic;
  signal frame_bit    : std_logic_vector( 3 downto 0);
  signal din_a_buf    : std_logic_vector(15 downto 0);
  signal din_b_buf    : std_logic_vector(15 downto 0);
  signal din_a_tmp    : std_logic_vector(15 downto 0);
  signal din_b_tmp    : std_logic_vector(15 downto 0);
  signal swap_en      : std_logic;

  type test_ptn_type is array(3 downto 0) of std_logic_vector(7 downto 0);
  signal test_ptn   : test_ptn_type;
  signal test_ptn_a : std_logic_vector(15 downto 0);
  signal test_ptn_b : std_logic_vector(15 downto 0);
  signal test_ptn_e : std_logic; -- enable
  
  -- Delay handling
  type delay_count_vec is array(8 downto 0) of std_logic_vector(8 downto 0);
  signal delay_count_in_data   : delay_count_vec;
  signal delay_count_out_data  : delay_count_vec;
  signal delay_load_data : std_logic_vector(8 downto 0);
  signal delay_load_data_buf : std_logic_vector(8 downto 0);
  
  signal delay_count_in_frame  : std_logic_vector(8 downto 0);
  signal delay_count_out_frame : std_logic_vector(8 downto 0);
  signal delay_load_frame      : std_logic;
  signal delay_load_frame_buf  : std_logic;
begin

  process(clk)
  begin
    if rising_edge(clk) then
      txenable  <= txenable_buf;
      frame_out <= frame;  -- debug
      frame_bit <= "00" & frame & frame;
    end if;
  end process;

  test_ptn_a <= test_ptn(0) & test_ptn(1);
  test_ptn_b <= test_ptn(2) & test_ptn(3);

  process(clk)
  begin
    if rising_edge(clk) then
      din_a_tmp <= din_a and x"ffff";
      din_b_tmp <= din_b and x"ffff";
    end if;
  end process;

  process(clk)
  begin
    if rising_edge(clk) then
      if test_ptn_e = '0' then
        if swap_en = '0' then
          din_a_buf <= din_a_tmp;
          din_b_buf <= din_b_tmp;
        else
          din_a_buf <= din_b_tmp;
          din_b_buf <= din_a_tmp;
        end if;
      else
        din_a_buf <= test_ptn_a;
        din_b_buf <= test_ptn_b;
      end if;
    end if;
  end process;

  dac_obuf_clk_inst : OBUFDS
    generic map (
      IOSTANDARD => "DEFAULT",
      SLEW       => "SLOW")
    port map (
      O  => dclk_p,
      OB => dclk_n,
      I  => clk_2x2);

  BUFGCE_DIV_inst : BUFGCE_DIV
    generic map(
      BUFGCE_DIVIDE => 2 )
    port map(
      O   =>  clk_div,
      CE  => '1',
      CLR => '0',
      I   => clk_2x );

  dac_obuf_frame_inst : dac_obuf
    port map(
      clk_div => clk_div,
      clk_2x  => clk_2x,
      clk     => clk,
      rst     => rst,
      I       => frame_bit,
      
      delay_count_in => delay_count_in_frame,
      delay_count_out => delay_count_out_frame,
      delay_load => delay_load_frame_buf, 
      
      O_p     => frame_p,
      O_n     => frame_n );

  dac_obuf_data_insts : for i in 0 to 7 generate
    dac_obuf_data_inst : dac_obuf
      port map(
        clk_div => clk_div,
        clk_2x  => clk_2x,
        clk     => clk,
        rst     => rst,
        I       => din_b_buf(i) & din_b_buf(i+8) & din_a_buf(i) & din_a_buf(i+8),
        
        delay_count_in => delay_count_in_data(i),
        delay_count_out => delay_count_out_data(i),
        delay_load => delay_load_data_buf(i),
        
        O_p     => dout_p(i),
        O_n     => dout_n(i));
  end generate dac_obuf_data_insts;

  addr_num <= to_integer(unsigned(rbcp_addr(7 downto 0)));
  delay_count_in_frame(8 downto 0) <= delay_count_in_data(8)(8 downto 0);
  delay_count_out_data(8)(8 downto 0) <= delay_count_out_frame(8 downto 0);

  -- Load signal buffering
  load_buf : for i in 0 to 8 generate 
    process (rbcp_addr, rbcp_we, addr_num) begin
      if (addr_num = i) and (rbcp_addr(15 downto 8) = x"02") and (rbcp_we = '1') then
        delay_load_data(i) <= '1';
      else 
        delay_load_data(i) <= '0';
      end if;
    end process;
  end generate load_buf;
  
  process (rbcp_addr, rbcp_we, addr_num) begin
    if (addr_num = 8) and (rbcp_addr(15 downto 8) = x"02") and (rbcp_we = '1') then
      delay_load_frame <= '1';
    else
      delay_load_frame <= '0';
    end if;
  end process;
  
  process(clk) begin
    if rising_edge(clk) then
      delay_load_data_buf(7 downto 0) <= delay_load_data(7 downto 0);
      delay_load_frame_buf <= delay_load_frame;
    end if;
  end process;

  delay_load_frame <= delay_load_data(8);

  DAC_rbcp_proc : process(clk)
  begin
    if rising_edge(clk) then
      rbcp_ack <= '0';
      rbcp_rd  <= (others => '0');
      frame    <= '0';                   -- 0x22000001
      if rst = '1' then
        txenable_buf <= '0';               -- 0x22000000
        swap_en      <= '0';               -- 0x22000002
        test_ptn_e   <= '0';               -- 0x22000003
        test_ptn     <= (others => (others => '0')); -- 0x230001xx
      else
        if rbcp_addr(31 downto 16) = x"2200" then
          if rbcp_addr(15 downto 0) = x"0000" then -- txenable
            if rbcp_we = '1' then
              rbcp_ack <= '1';
              txenable_buf <= rbcp_wd(0);
            elsif rbcp_re = '1' then
              rbcp_ack <= '1';
              rbcp_rd(0) <= txenable_buf;
            end if;
          elsif rbcp_addr(15 downto 0) = x"0001" then -- frame
            if rbcp_we = '1' then
              rbcp_ack <= '1';
              frame <= rbcp_wd(0);
            end if;
          elsif rbcp_addr(15 downto 0) = x"0002" then -- swap_en
            if rbcp_we = '1' then
              rbcp_ack <= '1';
              swap_en  <= rbcp_wd(0);
            elsif rbcp_re = '1' then
              rbcp_ack <= '1';
              rbcp_rd(0) <= swap_en;
            end if;
          elsif rbcp_addr(15 downto 0) = x"0003" then -- test_ptn_e
            if rbcp_we = '1' then
              rbcp_ack <= '1';
              test_ptn_e <= rbcp_wd(0);
            elsif rbcp_re = '1' then
              rbcp_ack <= '1';
              rbcp_rd(0) <= test_ptn_e;
            end if;
          elsif rbcp_addr(15 downto 8) = x"01" then -- Port A LSB
            if rbcp_we = '1' then
              rbcp_ack <= '1';
              delay_count_in_data(addr_num) <= rbcp_wd(7 downto 0);
            elsif rbcp_re = '1' then
              rbcp_ack <= '1';
              rbcp_rd(7 downto 0) <= delay_count_out_data(addr_num)(7 downto 0);
            end if;
          elsif rbcp_addr(15 downto 8) = x"02" then -- Port A MSB
            if rbcp_we = '1' then
              rbcp_ack <= '1';
              delay_count_in_data(addr_num)(8) <= rbcp_wd(0);
            elsif rbcp_re = '1' then
              rbcp_ack <= '1';
              rbcp_rd(0) <= delay_count_out_data(addr_num)(8);
            end if;
          end if;
        elsif rbcp_addr(31 downto 8) = x"230001" then -- test pattern
          if addr_num < 4 then
            if rbcp_we = '1' then
              rbcp_ack <= '1';
              test_ptn(addr_num) <= rbcp_wd;
            elsif rbcp_re = '1' then
              rbcp_ack <= '1';
              rbcp_rd <= test_ptn(addr_num);
            end if;
          end if;
        end if;
      end if;
    end if;
  end process;
end Behavioral;
