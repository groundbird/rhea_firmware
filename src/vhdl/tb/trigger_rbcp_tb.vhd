library IEEE;
use IEEE.STD_LOGIC_1164.all;

entity fifo_for_trigger is
  port (
    clk        : in  std_logic;
    wr_en      : in  std_logic;
    din        : in  std_logic_vector(55 downto 0);
    full       : out std_logic;
    rd_en      : in  std_logic;
    valid      : out std_logic;
    dout       : out std_logic_vector(55 downto 0);
    empty      : out std_logic;
    data_count : out std_logic_vector(9 downto 0));
end entity fifo_for_trigger;

architecture stub of fifo_for_trigger is
begin
  full       <= '0';
  valid      <= '0';
  dout       <= (others => '0');
  empty      <= '1';
  data_count <= (others => '0');
end architecture stub;

library IEEE;
use IEEE.STD_LOGIC_1164.all;

library work;
use work.rhea_pkg.all;

entity trigger_rbcp_tb is
end entity trigger_rbcp_tb;

architecture test of trigger_rbcp_tb is
  constant CLK_PERIOD : time := 4 ns;

  signal clk       : std_logic := '0';
  signal rst       : std_logic := '1';
  signal rbcp_we   : std_logic := '0';
  signal rbcp_re   : std_logic := '0';
  signal rbcp_ack  : std_logic;
  signal rbcp_addr : std_logic_vector(31 downto 0) := (others => '0');
  signal rbcp_wd   : std_logic_vector(7 downto 0) := (others => '0');
  signal rbcp_rd   : std_logic_vector(7 downto 0);
  signal data_in   : data_array(0 to N_CHANNEL*2-1, IQ_DS_DATA_WIDTH-1 downto 0) :=
                     (others => (others => '0'));
  signal data_out  : data_array(0 to N_CH_TRIG*2-1, IQ_DS_DATA_WIDTH-1 downto 0);
  signal valid     : std_logic;
  signal time_rst  : std_logic;
begin
  clk <= not clk after CLK_PERIOD/2;

  dut : entity work.trigger
    port map (
      clk       => clk,
      rst       => rst,
      rbcp_we   => rbcp_we,
      rbcp_re   => rbcp_re,
      rbcp_ack  => rbcp_ack,
      rbcp_addr => rbcp_addr,
      rbcp_wd   => rbcp_wd,
      rbcp_rd   => rbcp_rd,
      data_in   => data_in,
      data_we   => '0',
      fmt_busy  => '0',
      tcp_full  => '0',
      data_out  => data_out,
      valid     => valid,
      time_rst  => time_rst);

  stimulus : process
    procedure rbcp_write(
      constant address : in std_logic_vector(31 downto 0);
      constant value   : in std_logic_vector(7 downto 0)) is
    begin
      rbcp_addr <= address;
      rbcp_wd   <= value;
      rbcp_we   <= '1';
      loop
        wait until rising_edge(clk);
        wait for 0 ns;
        exit when rbcp_ack = '1';
      end loop;
      rbcp_we <= '0';
      wait until rising_edge(clk);
      wait until rising_edge(clk);
    end procedure;

    procedure rbcp_read_check(
      constant address  : in std_logic_vector(31 downto 0);
      constant expected : in std_logic_vector(7 downto 0)) is
      variable cycles : natural := 0;
    begin
      rbcp_addr <= address;
      rbcp_re   <= '1';
      loop
        wait until rising_edge(clk);
        wait for 0 ns;
        cycles := cycles + 1;
        assert cycles < 32 report "RBCP read timeout" severity failure;
        exit when rbcp_ack = '1';
      end loop;
      assert rbcp_rd = expected report "RBCP read data mismatch" severity failure;
      rbcp_re <= '0';
      for i in 0 to 5 loop
        wait until rising_edge(clk);
      end loop;
      assert rbcp_ack = '0' report "duplicate RBCP read acknowledgement" severity failure;
    end procedure;
  begin
    for i in 0 to 4 loop
      wait until rising_edge(clk);
    end loop;
    rst <= '0';
    wait until rising_edge(clk);

    rbcp_write(x"71000010", x"A5"); -- channel 0, minimum A, byte 0
    rbcp_write(x"71002524", x"5A"); -- channel 37, minimum B, byte 4
    rbcp_write(x"71003F37", x"C3"); -- channel 63, maximum A, byte 7
    rbcp_write(x"71002542", x"96"); -- channel 37, maximum B, byte 2
    rbcp_write(x"71003F00", x"01"); -- channel 63 enable, both A and B

    rbcp_read_check(x"71000010", x"A5");
    rbcp_read_check(x"71002524", x"5A");
    rbcp_read_check(x"71003F37", x"C3");
    rbcp_read_check(x"71002542", x"96");
    rbcp_read_check(x"71003F00", x"01");
    rbcp_read_check(x"71003E37", x"00"); -- neighbouring channel isolation

    report "trigger_rbcp_tb passed" severity note;
    std.env.finish;
  end process;
end architecture test;
