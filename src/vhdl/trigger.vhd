library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use IEEE.STD_LOGIC_MISC.all;

library work;
use work.rhea_pkg.all;

entity trigger is
  port(
    clk : in std_logic;
    rst : in std_logic;
    -- rbcp
    rbcp_we   : in  std_logic;
    rbcp_re   : in  std_logic;
    rbcp_ack  : out std_logic;
    rbcp_addr : in  std_logic_vector(31 downto 0);
    rbcp_wd   : in  std_logic_vector( 7 downto 0);
    rbcp_rd   : out std_logic_vector( 7 downto 0);
    -- in
    data_in   : in  data_array(0 to N_CHANNEL*2-1, IQ_DS_DATA_WIDTH-1 downto 0);
    data_we   : in  std_logic;
    fmt_busy  : in  std_logic;
    tcp_full  : in  std_logic;
    -- out
    data_out  : out data_array(0 to N_CH_TRIG*2-1, IQ_DS_DATA_WIDTH-1 downto 0);
    valid     : out std_logic;
    time_rst  : out std_logic);
end entity trigger;

architecture Behavioral of trigger is

  constant trig_pos_offset : natural := 1;
  constant IQ_BUF_WIDTH : natural := 64;
  subtype iq_buf_data is std_logic_vector(IQ_BUF_WIDTH-1 downto 0);
  type iq_buf_data_array is array (N_CH_TRIG*2-1 downto 0) of iq_buf_data;
  subtype trig_time_type is std_logic_vector(15 downto 0);  -- 0 to 1023
  type trig_time_array is array (N_CH_TRIG*2-1 downto 0) of trig_time_type;
  type trig_cond_array is array (N_CH_TRIG*2-1 downto 0) of boolean;

  component fifo_for_trigger is
    port(
      clk   : in  std_logic;
      wr_en : in  std_logic;
      din   : in  std_logic_vector(IQ_DS_DATA_WIDTH-1 downto 0);
      full  : out std_logic;
      rd_en : in  std_logic;
      valid : out std_logic;
      dout  : out std_logic_vector(IQ_DS_DATA_WIDTH-1 downto 0);
      empty : out std_logic;
      data_count : out std_logic_vector(9 downto 0));
  end component fifo_for_trigger;

  type trig_state is (init, idle, send, sleep, clear);
  signal state : trig_state;

  signal din_buf : iq_tri_ds_data_array;
  signal dwe_buf : std_logic;

  -- variable from RBCP
  signal sft_rst    : std_logic;
  signal en_trig    : std_logic;
  signal thre_min   : iq_tri_ds_data_array;
  signal thre_max   : iq_tri_ds_data_array;
  signal th_min_buf : iq_buf_data_array;
  signal th_max_buf : iq_buf_data_array;
  signal ch_enable  : std_logic_vector(N_CH_TRIG*2-1 downto 0);
  signal trig_pos   : trig_time_type;
  signal thre_cnt   : trig_time_type;
  signal trig_pos_int : natural range 0 to 2047;

  signal int_ch    : integer range 0 to 255;
  signal int_byte  : integer range 0 to   7;

  -- internal signal
  signal enable    : std_logic;
  signal ch_trig_c : trig_time_array;
  signal ch_trig   : std_logic_vector(N_CH_TRIG*2-1 downto 0);
  signal trig_cond   : trig_cond_array;
  signal trigger   : std_logic;

  -- fifo
  signal fifo_wr_en : std_logic;
  signal fifo_din   : iq_tri_ds_data_array;
  signal fifo_rd_en : std_logic;
  signal fifo_valid : std_logic;
  signal fifo_dout  : iq_tri_ds_data_array;
  signal fifo_empty : std_logic;
  signal fifo_count : std_logic_vector(9 downto 0);
  signal fifo_full  : std_logic;

begin

  INPUT_BUF_GEN1 : for i in 0 to N_CH_TRIG*2-1 generate
    INPUT_BUF_GEN2 : for j in 0 to IQ_DS_DATA_WIDTH-1 generate
      process(clk)
      begin
        if rising_edge(clk) then
          din_buf(i)(j) <= data_in(i, j);
        end if;
      end process;
    end generate;
  end generate;
  process(clk)
  begin
    if rising_edge(clk) then
      dwe_buf <= data_we;
    end if;
  end process;

  FIFO_INPUT_GEN1 : for i in 0 to N_CH_TRIG*2-1 generate
    FIFO_INPUT_GEN2 : for j in 0 to IQ_DS_DATA_WIDTH-1 generate
      process(clk)
      begin
        if rising_edge(clk) then
          fifo_din(i)(j) <= din_buf(i)(j);
        end if;
      end process;
    end generate;
  end generate;
  process(clk)
  begin
    if rising_edge(clk) then
      fifo_wr_en <= dwe_buf;
    end if;
  end process;

  FIFO_OUTPUT_GEN1 : for i in 0 to N_CH_TRIG*2-1 generate
    FIFO_OUTPUT_GEN2 : for j in 0 to IQ_DS_DATA_WIDTH-1 generate
      process(clk)
      begin
        if rising_edge(clk) then
          data_out(i, j) <= fifo_dout(i)(j);
        end if;
      end process;
    end generate;
  end generate;
  process(clk)
  begin
    if rising_edge(clk) then
      if state = send or state = sleep then
        valid <= fifo_valid;
      else
        valid <= '0';
      end if;
    end if;
  end process;

  TIME_RST_PROC : process(clk)
  begin
    if rising_edge(clk) then
      if state = init then
        time_rst <= '1';
      else
        time_rst <= '0';
      end if;
    end if;
  end process;

  ENABLE_PROC : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        enable <= '0';
      else
        if sft_rst = '1' then
          enable <= '0';
        elsif en_trig = '1' then
          enable <= '1';
        elsif state = send then
          enable <= '0';
        end if;
      end if;
    end if;
  end process;

  TRIGGER_CONDITION : for i in 0 to N_CH_TRIG*2-1 generate
    trig_cond(i) <= ((signed(din_buf(i)) < signed(thre_min(i))) or (signed(din_buf(i)) > signed(thre_max(i))));
  end generate;

  SEARCH_EVENT : for i in 0 to N_CH_TRIG*2-1 generate
    process(clk)
    begin
      if rising_edge(clk) then
        if dwe_buf = '1' then
          if (trig_cond(i)) then
            ch_trig_c(i) <= std_logic_vector(unsigned(ch_trig_c(i)) + 1);
          else
            ch_trig_c(i) <= (others => '0');
          end if;
        end if;
      end if;
    end process;
    process(clk)
    begin
      if rising_edge(clk) then
        if unsigned(ch_trig_c(i)) >= unsigned(thre_cnt) then
          ch_trig(i) <= '1';
        else
          ch_trig(i) <= '0';
        end if;
      end if;
    end process;
  end generate;
  TRIGGER_PROC : process(clk)
  begin
    if rising_edge(clk) then
      trigger <= or_reduce(ch_enable and ch_trig);
    end if;
  end process;

  FIFO_INST_0 : fifo_for_trigger
    port map(
      clk   => clk,
      wr_en => fifo_wr_en,
      din   => fifo_din(0),
      full  => fifo_full,
      rd_en => fifo_rd_en,
      valid => fifo_valid,
      dout  => fifo_dout(0),
      empty => fifo_empty,
      data_count => fifo_count);
  FIFO_INST_GEN : for i in 1 to N_CH_TRIG*2-1 generate
    FIFO_INST : fifo_for_trigger
      port map(
        clk   => clk,
        wr_en => fifo_wr_en,
        din   => fifo_din(i),
        full  => open,
        rd_en => fifo_rd_en,
        valid => open,
        dout  => fifo_dout(i),
        empty => open,
        data_count => open);
  end generate;

  process(clk)
  begin
    if rising_edge(clk) then
      trig_pos_int <= to_integer(unsigned(trig_pos) + unsigned(thre_cnt) + TO_UNSIGNED(trig_pos_offset, 16));
    end if;
  end process;

  STATE_PROC : process(clk)
    variable send_cnt : integer range 0 to 1024;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        state <= clear;
        send_cnt := 0;
        fifo_rd_en <= '0';
      elsif sft_rst = '1' then
        state <= init;
      else
        case state is
          when clear =>
            fifo_rd_en <= '1';
            if fifo_empty = '1' then
              state <= init;
              fifo_rd_en <= '0';
            end if;

          when init =>
            fifo_rd_en <= '0';
            if unsigned(fifo_count) > trig_pos_int then
              fifo_rd_en <= '1';
            elsif unsigned(fifo_count) = trig_pos_int then
              state <= idle;
            end if;

          when idle =>
            fifo_rd_en <= '0';
            if unsigned(fifo_count) > trig_pos_int then
              fifo_rd_en <= '1';
            end if;
            if enable = '1' and trigger = '1' then
              state <= send;
              send_cnt := 0;
            end if;

          when send =>
            if fifo_empty = '0' and fmt_busy = '0' and tcp_full = '0' then
              if send_cnt = 1024 then
                state <= init;
              else
                fifo_rd_en <= '1';
                state <= sleep;
                send_cnt := send_cnt + 1;
              end if;
            end if;

          when sleep =>
            fifo_rd_en <= '0';
            if fmt_busy = '1' then
              state <= send;
            end if;

          when others =>
            state <= clear;
            fifo_rd_en <= '0';

        end case;
      end if;
    end if;
  end process;

  int_ch   <= to_integer(unsigned(rbcp_addr(15 downto 8)));
  int_byte <= to_integer(unsigned(rbcp_addr( 3 downto 0)));
  RBCP_PROC : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        rbcp_ack <= '0';
        rbcp_rd  <= (others => '0');
        sft_rst  <= '0';
        en_trig  <= '0';
        trig_pos  <= (others => '0');
        ch_enable <= (others => '0');
        th_min_buf <= (others => (others => '0'));
        th_max_buf <= (others => (others => '0'));
        thre_cnt  <= (others => '0');

      else
        rbcp_ack <= '0';
        rbcp_rd  <= (others => '0');
        sft_rst  <= '0';
        en_trig  <= '0';

        if rbcp_addr(31 downto 16) = x"7000" then

          if rbcp_addr(15 downto 0) = x"0000" then
            if rbcp_we = '1' then
              rbcp_ack <= '1';
              if rbcp_wd(0) = '0' then
                sft_rst <= '1';
              else
                en_trig <= '1';
              end if;
            elsif rbcp_re = '1' then
              rbcp_ack <= '1';
              rbcp_rd(0) <= enable;
            end if;

          elsif rbcp_addr(15 downto 4) = x"001" then
            if int_byte < 2 then
              if rbcp_we = '1' then
                rbcp_ack <= '1';
                trig_pos((1-int_byte)*8 + 7 downto (1-int_byte)*8) <= rbcp_wd;
              elsif rbcp_re = '1' then
                rbcp_ack <= '1';
                rbcp_rd  <= trig_pos((1-int_byte)*8 + 7 downto (1-int_byte)*8);
              end if;
            end if;

          elsif rbcp_addr(15 downto 4) = x"002" then
            if int_byte < 2 then
              if rbcp_we = '1' then
                rbcp_ack <= '1';
                thre_cnt((1-int_byte)*8 + 7 downto (1-int_byte)*8) <= rbcp_wd;
              elsif rbcp_re = '1' then
                rbcp_ack <= '1';
                rbcp_rd  <= thre_cnt((1-int_byte)*8 + 7 downto (1-int_byte)*8);
              end if;
            end if;

          end if;

        elsif rbcp_addr(31 downto 16) = x"7100" then
          if int_ch < N_CH_TRIG then

            if rbcp_addr(7 downto 0) = x"00" then
              if rbcp_we = '1' then
                rbcp_ack <= '1';
                ch_enable(int_ch*2+0) <= rbcp_wd(0);
                ch_enable(int_ch*2+1) <= rbcp_wd(0);
              elsif rbcp_re = '1' then
                rbcp_ack <= '1';
                rbcp_rd(0) <= ch_enable(int_ch*2);
              end if;
            end if;

            if rbcp_addr(7 downto 4) = x"1" then
              if int_byte < 8 then
                if rbcp_we = '1' then
                  rbcp_ack <= '1';
                  th_min_buf(int_ch*2+0)((7-int_byte)*8 + 7 downto (7-int_byte)*8) <= rbcp_wd;
                elsif rbcp_re = '1' then
                  rbcp_ack <= '1';
                  rbcp_rd <= th_min_buf(int_ch*2+0)((7-int_byte)*8 + 7 downto (7-int_byte)*8);
                end if;
              end if;

            elsif rbcp_addr(7 downto 4) = x"2" then
              if int_byte < 8 then
                if rbcp_we = '1' then
                  rbcp_ack <= '1';
                  th_min_buf(int_ch*2+1)((7-int_byte)*8 + 7 downto (7-int_byte)*8) <= rbcp_wd;
                elsif rbcp_re = '1' then
                  rbcp_ack <= '1';
                  rbcp_rd <= th_min_buf(int_ch*2+1)((7-int_byte)*8 + 7 downto (7-int_byte)*8);
                end if;
              end if;

            elsif rbcp_addr(7 downto 4) = x"3" then
              if int_byte < 8 then
                if rbcp_we = '1' then
                  rbcp_ack <= '1';
                  th_max_buf(int_ch*2+0)((7-int_byte)*8 + 7 downto (7-int_byte)*8) <= rbcp_wd;
                elsif rbcp_re = '1' then
                  rbcp_ack <= '1';
                  rbcp_rd <= th_max_buf(int_ch*2+0)((7-int_byte)*8 + 7 downto (7-int_byte)*8);
                end if;
              end if;

            elsif rbcp_addr(7 downto 4) = x"4" then
              if int_byte < 8 then
                if rbcp_we = '1' then
                  rbcp_ack <= '1';
                  th_max_buf(int_ch*2+1)((7-int_byte)*8 + 7 downto (7-int_byte)*8) <= rbcp_wd;
                elsif rbcp_re = '1' then
                  rbcp_ack <= '1';
                  rbcp_rd <= th_max_buf(int_ch*2+1)((7-int_byte)*8 + 7 downto (7-int_byte)*8);
                end if;
              end if;

            end if;
          end if;
        end if;
      end if;
    end if;
  end process;
  THRESHOLD_BUF_GEN1 : for ch in 0 to N_CH_TRIG*2-1 generate
    THRESHOLD_BUF_GEN2 : for bitn in 0 to IQ_DS_DATA_WIDTH-1 generate
      process(clk)
      begin
        if rising_edge(clk) then
          thre_min(ch)(bitn) <= th_min_buf(ch)(bitn);
        end if;
      end process;
      process(clk)
      begin
        if rising_edge(clk) then
          thre_max(ch)(bitn) <= th_max_buf(ch)(bitn);
        end if;
      end process;
    end generate;
  end generate;

end architecture Behavioral;
