library IEEE;
use IEEE.STD_LOGIC_1164.all;

-- Return the external RBCP acknowledgement and read data to the internal
-- clock domain. External slaves emit a one-cycle acknowledgement; the toggle
-- preserves it until the internal domain observes it.
entity rbcp_transfer_to_sitcp is
  port(
    rst     : in  std_logic;
    clk_ext : in  std_logic;
    clk_int : in  std_logic;
    rd_ext  : in  std_logic_vector(7 downto 0);
    ack_ext : in  std_logic;
    rd_int  : out std_logic_vector(7 downto 0);
    ack_int : out std_logic);
end entity rbcp_transfer_to_sitcp;

architecture Behavioral of rbcp_transfer_to_sitcp is
  signal ack_toggle : std_logic := '0';
  signal ack_seen   : std_logic := '0';
  signal ack_pending : std_logic := '0';
  signal rd_hold    : std_logic_vector(7 downto 0) := (others => '0');

  attribute ASYNC_REG : string;
  attribute SHREG_EXTRACT : string;
  signal ack_meta, ack_sync : std_logic := '0';
  signal rd_meta, rd_sync : std_logic_vector(7 downto 0) := (others => '0');
  attribute ASYNC_REG of ack_meta : signal is "TRUE";
  attribute ASYNC_REG of ack_sync : signal is "TRUE";
  attribute ASYNC_REG of rd_meta : signal is "TRUE";
  attribute ASYNC_REG of rd_sync : signal is "TRUE";
  attribute SHREG_EXTRACT of ack_meta : signal is "NO";
  attribute SHREG_EXTRACT of ack_sync : signal is "NO";
  attribute SHREG_EXTRACT of rd_meta : signal is "NO";
  attribute SHREG_EXTRACT of rd_sync : signal is "NO";
begin
  Source_Response : process(clk_ext)
  begin
    if rising_edge(clk_ext) then
      if rst = '1' then
        ack_toggle <= '0';
        rd_hold <= (others => '0');
      elsif ack_ext = '1' then
        rd_hold <= rd_ext;
        ack_toggle <= not ack_toggle;
      end if;
    end if;
  end process;

  Destination_Response : process(clk_int)
  begin
    if rising_edge(clk_int) then
      if rst = '1' then
        ack_meta <= '0';
        ack_sync <= '0';
        rd_meta <= (others => '0');
        rd_sync <= (others => '0');
        ack_seen <= '0';
        ack_pending <= '0';
        rd_int <= (others => '0');
        ack_int <= '0';
      else
        ack_meta <= ack_toggle;
        ack_sync <= ack_meta;
        rd_meta <= rd_hold;
        rd_sync <= rd_meta;
        ack_int <= '0';
        -- As on the request path, let the bundled read data settle for one
        -- extra destination cycle after the synchronized toggle changes.
        if ack_pending = '1' then
          ack_pending <= '0';
          rd_int <= rd_sync;
          ack_int <= '1';
        elsif ack_sync /= ack_seen then
          ack_seen <= ack_sync;
          ack_pending <= '1';
        end if;
      end if;
    end if;
  end process;
end architecture Behavioral;
