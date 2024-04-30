-----------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 2015/05/28 10:55:26
-- Design Name: 
-- Module Name: formatter - Behavioral
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

entity formatter is
  generic (
    d_byte     : integer;     -- IQ_DS_DATA_WIDTH / 8
    d_num      : integer);    -- N_CHANNEL * 2        -- d_byte bytes * d_num
  port (
    clk        : in  std_logic;
    rst        : in  std_logic;
    ts_rst     : in  std_logic;
    r_num      : in  integer range 0 to d_num;
    wr_en      : in  std_logic;
    sync_mode  : in  std_logic; -- if sync_mode = 1, format for sync_cnt
    sg_swp_trg : in  std_logic;
    n_rot      : in  std_logic_vector(39 downto 0); -- for sync_mode
    n_rot_en   : in  std_logic;
    din        : in  data_array(0 to d_num-1, d_byte*8-1 downto 0);
    dout       : out std_logic_vector(7 downto 0);
    valid      : out std_logic;
    busy       : out std_logic);
end entity formatter;

architecture Behavioral of formatter is

  -- data     : header [1] + ts(i_q ) [5] + data (i_q   ) + footer [1]; [bytes]
  ------------> 'ff'       + ts(i_q ) [5] + data (i_q   ) + 'ee'      ; [bytes]
  -- sync_cnt : header [1] + ts(sync) [5] + data (offset) + footer [1]; [bytes]
  ------------> 'f5'       + ts(sync) [5] + data (offset) + 'ee'      ; [bytes]

  signal r_num_buf : integer range 0 to d_num;

  signal ts        : std_logic_vector(39 downto 0);
  signal ts_fmt    : byte_array(4 downto 0);
  signal n_rot_fmt : byte_array(4 downto 0);
  signal din_buf   : data_array(0 to d_num-1, d_byte*8-1 downto 0);
  signal din_fmt   : byte_array(d_num * d_byte - 1 downto 0);
  signal cnt       : integer range 0 to (d_num * d_byte + 4); -- max(d_num * d_byte - 1, 4)
  signal trg_reg : std_logic;
  signal trg_rst : std_logic;

  type fmt_state is (reset, idle, send_header, send_ts, send_data, send_footer, fini);
  signal s_fmt     : fmt_state;

begin

  process(clk)
  begin
    if rising_edge(clk) then
      if s_fmt = idle then
        if r_num = 0 then
          r_num_buf <= d_num;
        else
          r_num_buf <= r_num;
        end if;
      end if;
    end if;
  end process;

  busy  <= '1' when s_fmt /= idle else '0';

  process(clk)
  begin
    if rising_edge(clk) then
      if s_fmt = send_header or
        s_fmt = send_ts      or
        s_fmt = send_data    or
        s_fmt = send_footer  then
        valid <= '1';
      else
        valid <= '0';
      end if;
    end if;
  end process;

  process(clk)
  begin
    if rising_edge(clk) then
      case s_fmt is
        when send_header =>
          if sync_mode = '1' then -- for sync_mode, header -> 'f5'
            dout <= x"f5";
          elsif trg_reg = '1' then -- sg_swp, header -> 'aa'
            dout <= x"aa";
            trg_rst <= '1';
          else
            dout <= x"ff";
          end if;
        when send_ts     =>
          if sync_mode = '1' then
            dout <= n_rot_fmt(cnt);
          else
            dout <= ts_fmt(cnt);
            trg_rst <= '0';
          end if;
        when send_data   => dout <= din_fmt(cnt);
        when send_footer => dout <= x"ee";
        when others      => dout <= x"00";
      end case;
    end if;
  end process;

  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' or trg_rst = '1' or ts_rst = '1' then
        trg_reg <= '0';
      elsif sg_swp_trg = '1' then
        trg_reg <= '1';
      end if;
    end if;
  end process;

  Formatter_SM : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        s_fmt <= reset;
        cnt   <= 0;
      else
        case s_fmt is
          when reset =>
            s_fmt <= idle;
            cnt   <= 0;

          when idle =>
            if wr_en = '1' then
              s_fmt <= send_header;
            end if;

          when send_header =>
            cnt <= 4;
            s_fmt <= send_ts;

          when send_ts =>
            if cnt <= 0 then
              cnt <= d_num * d_byte - 1;
              s_fmt <= send_data;
            else
              cnt <= cnt - 1;
            end if;

          when send_data =>
            if cnt <= (d_num - r_num_buf) * d_byte then
              s_fmt <= send_footer;
            else
              cnt <= cnt - 1;
            end if;

          when send_footer =>
            s_fmt <= fini;

          when fini => s_fmt <= idle;

          when others => s_fmt <= idle;
        end case;
      end if;
    end if;
  end process;

  Timestamp_gen : for i in 0 to 4 generate
    process(clk)
    begin
      if rising_edge(clk) then
        if s_fmt = idle and wr_en = '1' then
          ts_fmt(i) <= ts(8*i+7 downto 8*i);
        end if;
      end if;
    end process;
  end generate Timestamp_gen;

  N_rotate_gen : for i in 0 to 4 generate
    process(clk)
    begin
      if rising_edge(clk) then
        if n_rot_en = '1' then
          n_rot_fmt(i) <= n_rot(8*i+7 downto 8*i);
        end if;
      end if;
    end process;
  end generate N_rotate_gen;
  
  Data_gen : for n in 0 to d_num-1 generate
    Data_Byte_gen : for i in 0 to d_byte-1 generate
      Data_bit_gen : for j in 0 to 7 generate
        process(clk)
        begin
          if rising_edge(clk) then
            din_fmt((d_num-n-1) * d_byte + i)(j) <= din_buf(n, 8*i+j);
          end if;
        end process;
      end generate Data_bit_gen;
    end generate Data_Byte_gen;
  end generate Data_gen;
  
  Timestampe_proc : process(clk)
  begin
    if rising_edge(clk) then
      if ts_rst = '1' or rst = '1' then
        ts <= (others => '0');
      elsif s_fmt = fini then
        ts <= ts + '1';
      end if;
    end if;
  end process;

  Data_proc : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        din_buf <= (others => (others => '0'));
      elsif s_fmt = idle and wr_en = '1' then
        din_buf <= din;
      end if;
    end if;
  end process;

end architecture Behavioral;
