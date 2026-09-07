library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use STD.ENV.all;

entity rbcp_transfer_toggle_tb is
end entity;

architecture test of rbcp_transfer_toggle_tb is
  signal rst : std_logic := '1';
  signal clk_int : std_logic := '0';
  signal clk_ext : std_logic := '0';
  signal we_int, re_int : std_logic := '0';
  signal addr_int : std_logic_vector(31 downto 0) := (others => '0');
  signal wd_int : std_logic_vector(7 downto 0) := (others => '0');
  signal we_ext, re_ext : std_logic;
  signal addr_ext : std_logic_vector(31 downto 0);
  signal wd_ext : std_logic_vector(7 downto 0);
  signal ack_ext : std_logic := '0';
  signal rd_ext : std_logic_vector(7 downto 0) := (others => '0');
  signal ack_int : std_logic;
  signal rd_int : std_logic_vector(7 downto 0);
begin
  clk_int <= not clk_int after 2.5 ns;
  clk_ext <= not clk_ext after 2.6 ns;

  request_cdc : entity work.rbcp_transfer_from_sitcp
    port map (
      rst => rst, clk_int => clk_int, clk_ext => clk_ext,
      we_int => we_int, re_int => re_int, addr_int => addr_int,
      wd_int => wd_int, we_ext => we_ext, re_ext => re_ext,
      addr_ext => addr_ext, wd_ext => wd_ext);

  response_cdc : entity work.rbcp_transfer_to_sitcp
    port map (
      rst => rst, clk_ext => clk_ext, clk_int => clk_int,
      rd_ext => rd_ext, ack_ext => ack_ext,
      rd_int => rd_int, ack_int => ack_int);

  stimulus : process
    variable expected_addr : std_logic_vector(31 downto 0);
    variable expected_wd : std_logic_vector(7 downto 0);
    variable expected_rd : std_logic_vector(7 downto 0);
    variable is_write : boolean;
    variable delay_cycles : integer;
  begin
    wait for 50 ns;
    wait until rising_edge(clk_int);
    rst <= '0';

    for index in 0 to 1999 loop
      expected_addr := std_logic_vector(to_unsigned(16#22000000# + index, 32));
      expected_wd := std_logic_vector(to_unsigned(index mod 256, 8));
      expected_rd := not expected_wd;
      is_write := (index mod 3) /= 0;

      wait until rising_edge(clk_int);
      addr_int <= expected_addr;
      wd_int <= expected_wd;
      if is_write then
        we_int <= '1';
      else
        re_int <= '1';
      end if;
      wait until rising_edge(clk_int);
      we_int <= '0';
      re_int <= '0';

      wait until rising_edge(clk_ext) and (we_ext = '1' or re_ext = '1');
      assert addr_ext = expected_addr report "request address mismatch" severity failure;
      assert wd_ext = expected_wd report "request data mismatch" severity failure;
      assert (we_ext = '1') = is_write report "request direction mismatch" severity failure;

      delay_cycles := (index * 17) mod 73;
      for delay_index in 1 to delay_cycles loop
        wait until rising_edge(clk_ext);
      end loop;
      rd_ext <= expected_rd;
      ack_ext <= '1';
      wait until rising_edge(clk_ext);
      ack_ext <= '0';

      wait until rising_edge(clk_int) and ack_int = '1';
      assert rd_int = expected_rd report "response data mismatch" severity failure;
    end loop;

    report "PASS: RBCP request/response toggle CDC with variable latency";
    finish;
  end process;

  watchdog : process
  begin
    wait for 5 ms;
    assert false report "simulation timeout" severity failure;
  end process;
end architecture;
