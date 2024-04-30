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
    rbcp_rd   : out std_logic_vector( 7 downto 0));
end info;

architecture Behavioral of info is

--  signal rbcp_we_buf   : std_logic;
  signal rbcp_re_buf   : std_logic;
  signal rbcp_ack_buf  : std_logic;
  signal rbcp_addr_buf : std_logic_vector(31 downto 0);
--  signal rbcp_wd_buf   : std_logic_vector( 7 downto 0);
  signal rbcp_rd_buf   : std_logic_vector( 7 downto 0);

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

  rbcp_buffering : process(clk)
  begin
    if rising_edge(clk) then
--      rbcp_we_buf   <= rbcp_we;
      rbcp_re_buf   <= rbcp_re;
      rbcp_addr_buf <= rbcp_addr;
--      rbcp_wd_buf   <= rbcp_wd;
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

    end if;
  end process;

end Behavioral;
