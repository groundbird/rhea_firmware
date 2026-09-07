library IEEE;
use IEEE.STD_LOGIC_1164.all;

-- Transfer the single outstanding RBCP request into the external clock
-- domain. The source holds the payload until the independently synchronized
-- acknowledgement returns, so a toggle handshake is sufficient and avoids
-- losing one-cycle requests in an asynchronous FIFO.
entity rbcp_transfer_from_sitcp is
  port(
    rst      : in  std_logic;
    clk_int  : in  std_logic;
    clk_ext  : in  std_logic;
    we_int   : in  std_logic;
    re_int   : in  std_logic;
    addr_int : in  std_logic_vector(31 downto 0);
    wd_int   : in  std_logic_vector( 7 downto 0);
    we_ext   : out std_logic;
    re_ext   : out std_logic;
    addr_ext : out std_logic_vector(31 downto 0);
    wd_ext   : out std_logic_vector( 7 downto 0));
end entity rbcp_transfer_from_sitcp;

architecture Behavioral of rbcp_transfer_from_sitcp is
  signal request_toggle : std_logic := '0';
  signal request_seen   : std_logic := '0';
  signal request_pending : std_logic := '0';
  signal we_hold        : std_logic := '0';
  signal addr_hold      : std_logic_vector(31 downto 0) := (others => '0');
  signal wd_hold        : std_logic_vector(7 downto 0) := (others => '0');

  attribute ASYNC_REG : string;
  attribute SHREG_EXTRACT : string;
  signal request_meta, request_sync : std_logic := '0';
  signal we_meta, we_sync : std_logic := '0';
  signal addr_meta, addr_sync : std_logic_vector(31 downto 0) := (others => '0');
  signal wd_meta, wd_sync : std_logic_vector(7 downto 0) := (others => '0');
  attribute ASYNC_REG of request_meta : signal is "TRUE";
  attribute ASYNC_REG of request_sync : signal is "TRUE";
  attribute ASYNC_REG of we_meta : signal is "TRUE";
  attribute ASYNC_REG of we_sync : signal is "TRUE";
  attribute ASYNC_REG of addr_meta : signal is "TRUE";
  attribute ASYNC_REG of addr_sync : signal is "TRUE";
  attribute ASYNC_REG of wd_meta : signal is "TRUE";
  attribute ASYNC_REG of wd_sync : signal is "TRUE";
  attribute SHREG_EXTRACT of request_meta : signal is "NO";
  attribute SHREG_EXTRACT of request_sync : signal is "NO";
  attribute SHREG_EXTRACT of we_meta : signal is "NO";
  attribute SHREG_EXTRACT of we_sync : signal is "NO";
  attribute SHREG_EXTRACT of addr_meta : signal is "NO";
  attribute SHREG_EXTRACT of addr_sync : signal is "NO";
  attribute SHREG_EXTRACT of wd_meta : signal is "NO";
  attribute SHREG_EXTRACT of wd_sync : signal is "NO";
begin
  Source_Request : process(clk_int)
  begin
    if rising_edge(clk_int) then
      if rst = '1' then
        request_toggle <= '0';
        we_hold <= '0';
        addr_hold <= (others => '0');
        wd_hold <= (others => '0');
      elsif we_int = '1' or re_int = '1' then
        we_hold <= we_int;
        addr_hold <= addr_int;
        wd_hold <= wd_int;
        request_toggle <= not request_toggle;
      end if;
    end if;
  end process;

  Destination_Request : process(clk_ext)
  begin
    if rising_edge(clk_ext) then
      if rst = '1' then
        request_meta <= '0';
        request_sync <= '0';
        we_meta <= '0';
        we_sync <= '0';
        addr_meta <= (others => '0');
        addr_sync <= (others => '0');
        wd_meta <= (others => '0');
        wd_sync <= (others => '0');
        request_seen <= '0';
        request_pending <= '0';
        we_ext <= '0';
        re_ext <= '0';
        addr_ext <= (others => '0');
        wd_ext <= (others => '0');
      else
        request_meta <= request_toggle;
        request_sync <= request_meta;
        we_meta <= we_hold;
        we_sync <= we_meta;
        addr_meta <= addr_hold;
        addr_sync <= addr_meta;
        wd_meta <= wd_hold;
        wd_sync <= wd_meta;
        we_ext <= '0';
        re_ext <= '0';
        -- The payload and toggle originate on the same source edge. Wait one
        -- additional destination cycle after detecting the toggle so every
        -- payload bit has settled through its two-stage synchronizer.
        if request_pending = '1' then
          request_pending <= '0';
          addr_ext <= addr_sync;
          wd_ext <= wd_sync;
          we_ext <= we_sync;
          re_ext <= not we_sync;
        elsif request_sync /= request_seen then
          request_seen <= request_sync;
          request_pending <= '1';
        end if;
      end if;
    end if;
  end process;
end architecture Behavioral;
