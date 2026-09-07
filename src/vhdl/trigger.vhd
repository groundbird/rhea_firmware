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
  constant TRIGGER_GROUP_SIZE : natural := 8;
  constant N_TRIGGER_GROUP : natural := (N_CH_TRIG*2 + TRIGGER_GROUP_SIZE - 1) / TRIGGER_GROUP_SIZE;
  constant RBCP_MUX_GROUP_SIZE : natural := 8;
  constant N_RBCP_MUX_GROUP : natural := (N_CH_TRIG*2 + RBCP_MUX_GROUP_SIZE - 1) / RBCP_MUX_GROUP_SIZE;
  constant IQ_BUF_WIDTH : natural := 64;
  subtype iq_buf_data is std_logic_vector(IQ_BUF_WIDTH-1 downto 0);
  type iq_buf_data_array is array (N_CH_TRIG*2-1 downto 0) of iq_buf_data;
  type rbcp_read_group_array is array (0 to N_RBCP_MUX_GROUP-1) of iq_buf_data;
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
  signal rbcp_we_buf : std_logic;
  signal rbcp_re_buf : std_logic;
  signal rbcp_addr_buf : std_logic_vector(31 downto 0);
  signal rbcp_wd_buf : std_logic_vector(7 downto 0);
  signal rbcp_we_dec : std_logic;
  signal rbcp_re_dec : std_logic;
  signal rbcp_wd_dec : std_logic_vector(7 downto 0);
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
  signal int_byte  : integer range 0 to  15;
  signal int_ch_dec   : integer range 0 to 255;
  signal int_byte_dec : integer range 0 to 15;
  signal sel_ctl_reg      : std_logic;
  signal sel_trig_pos_reg : std_logic;
  signal sel_thre_cnt_reg : std_logic;
  signal sel_enable_reg   : std_logic;
  signal sel_th_min_a_reg : std_logic;
  signal sel_th_min_b_reg : std_logic;
  signal sel_th_max_a_reg : std_logic;
  signal sel_th_max_b_reg : std_logic;

  -- Pipeline the large per-channel RBCP mux.  A flat 128-entry read mux and
  -- its write decoder do not meet the 250 MHz ADC-domain clock at 64 channels.
  signal rbcp_read_groups       : rbcp_read_group_array;
  signal rbcp_read_word         : iq_buf_data;
  signal rbcp_read_group_index  : integer range 0 to N_RBCP_MUX_GROUP-1;
  signal rbcp_read_byte_stage1  : integer range 0 to 7;
  signal rbcp_read_byte_stage2  : integer range 0 to 7;
  signal rbcp_read_enable_stage1 : std_logic;
  signal rbcp_read_enable_stage2 : std_logic;
  signal rbcp_read_stage1_valid : std_logic;
  signal rbcp_read_stage2_valid : std_logic;
  signal rbcp_read_busy         : std_logic;

  signal ch_enable_write_onehot : std_logic_vector(N_CH_TRIG*2-1 downto 0);
  signal th_min_write_onehot    : std_logic_vector(N_CH_TRIG*2-1 downto 0);
  signal th_max_write_onehot    : std_logic_vector(N_CH_TRIG*2-1 downto 0);
  signal threshold_write_byte   : std_logic_vector(7 downto 0);
  signal threshold_write_data   : std_logic_vector(7 downto 0);
  signal ch_enable_write_data   : std_logic;

  -- internal signal
  signal enable    : std_logic;
  signal ch_enable_local : std_logic_vector(N_CH_TRIG*2-1 downto 0);
  signal thre_cnt_local  : trig_time_array;
  signal ch_trig_c : trig_time_array;
  signal ch_trig   : std_logic_vector(N_CH_TRIG*2-1 downto 0);
  signal trig_group : std_logic_vector(N_TRIGGER_GROUP-1 downto 0);
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

  attribute keep : string;
  attribute keep of rbcp_addr_buf : signal is "true";
  attribute keep of rbcp_we_buf : signal is "true";
  attribute keep of rbcp_re_buf : signal is "true";

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

  process(clk)
  begin
    if rising_edge(clk) then
      rbcp_we_buf   <= rbcp_we;
      rbcp_re_buf   <= rbcp_re;
      rbcp_addr_buf <= rbcp_addr;
      rbcp_wd_buf   <= rbcp_wd;
    end if;
  end process;

  process(clk)
  begin
    if rising_edge(clk) then
      rbcp_we_dec <= rbcp_we_buf;
      rbcp_re_dec <= rbcp_re_buf;
      rbcp_wd_dec <= rbcp_wd_buf;
      int_ch_dec  <= int_ch;
      int_byte_dec <= int_byte;

      sel_ctl_reg      <= '0';
      sel_trig_pos_reg <= '0';
      sel_thre_cnt_reg <= '0';
      sel_enable_reg   <= '0';
      sel_th_min_a_reg <= '0';
      sel_th_min_b_reg <= '0';
      sel_th_max_a_reg <= '0';
      sel_th_max_b_reg <= '0';

      if rbcp_addr_buf(31 downto 16) = x"7000" then
        if rbcp_addr_buf(15 downto 0) = x"0000" then
          sel_ctl_reg <= '1';
        elsif rbcp_addr_buf(15 downto 4) = x"001" then
          sel_trig_pos_reg <= '1';
        elsif rbcp_addr_buf(15 downto 4) = x"002" then
          sel_thre_cnt_reg <= '1';
        end if;
      elsif rbcp_addr_buf(31 downto 16) = x"7100" then
        if int_ch < N_CH_TRIG then
          if rbcp_addr_buf(7 downto 0) = x"00" then
            sel_enable_reg <= '1';
          elsif rbcp_addr_buf(7 downto 4) = x"1" then
            sel_th_min_a_reg <= '1';
          elsif rbcp_addr_buf(7 downto 4) = x"2" then
            sel_th_min_b_reg <= '1';
          elsif rbcp_addr_buf(7 downto 4) = x"3" then
            sel_th_max_a_reg <= '1';
          elsif rbcp_addr_buf(7 downto 4) = x"4" then
            sel_th_max_b_reg <= '1';
          end if;
        end if;
      end if;
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
        ch_enable_local(i) <= ch_enable(i);
        thre_cnt_local(i)  <= thre_cnt;
      end if;
    end process;
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
        if unsigned(ch_trig_c(i)) >= unsigned(thre_cnt_local(i)) then
          ch_trig(i) <= '1';
        else
          ch_trig(i) <= '0';
        end if;
      end if;
    end process;
  end generate;
  TRIGGER_GROUP_GEN : for grp in 0 to N_TRIGGER_GROUP-1 generate
    process(clk)
      variable hit : std_logic;
      variable idx_lo : natural;
      variable idx_hi : natural;
    begin
      if rising_edge(clk) then
        hit := '0';
        idx_lo := grp * TRIGGER_GROUP_SIZE;
        idx_hi := idx_lo + TRIGGER_GROUP_SIZE - 1;
        if idx_hi > N_CH_TRIG*2-1 then
          idx_hi := N_CH_TRIG*2-1;
        end if;
        for idx in idx_lo to idx_hi loop
          hit := hit or (ch_enable_local(idx) and ch_trig(idx));
        end loop;
        trig_group(grp) <= hit;
      end if;
    end process;
  end generate;
  TRIGGER_PROC : process(clk)
  begin
    if rising_edge(clk) then
      trigger <= or_reduce(trig_group);
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

  int_ch   <= to_integer(unsigned(rbcp_addr_buf(15 downto 8)));
  int_byte <= to_integer(unsigned(rbcp_addr_buf( 3 downto 0)));
  RBCP_PROC : process(clk)
    variable entry_index : natural range 0 to N_CH_TRIG*2-1;
    variable lane_index  : natural range 0 to RBCP_MUX_GROUP_SIZE-1;
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
        rbcp_read_groups <= (others => (others => '0'));
        rbcp_read_word <= (others => '0');
        rbcp_read_group_index <= 0;
        rbcp_read_byte_stage1 <= 0;
        rbcp_read_byte_stage2 <= 0;
        rbcp_read_enable_stage1 <= '0';
        rbcp_read_enable_stage2 <= '0';
        rbcp_read_stage1_valid <= '0';
        rbcp_read_stage2_valid <= '0';
        rbcp_read_busy <= '0';
        ch_enable_write_onehot <= (others => '0');
        th_min_write_onehot <= (others => '0');
        th_max_write_onehot <= (others => '0');
        threshold_write_byte <= (others => '0');
        threshold_write_data <= (others => '0');
        ch_enable_write_data <= '0';

      else
        rbcp_ack <= '0';
        rbcp_rd  <= (others => '0');
        sft_rst  <= '0';
        en_trig  <= '0';
        rbcp_read_stage1_valid <= '0';
        rbcp_read_stage2_valid <= rbcp_read_stage1_valid;
        ch_enable_write_onehot <= (others => '0');
        th_min_write_onehot <= (others => '0');
        th_max_write_onehot <= (others => '0');
        threshold_write_byte <= (others => '0');

        -- Apply writes from registered one-hot decoders.  Each threshold
        -- register now sees only a small local enable cone.
        for entry in 0 to N_CH_TRIG*2-1 loop
          if ch_enable_write_onehot(entry) = '1' then
            ch_enable(entry) <= ch_enable_write_data;
          end if;
          for byte_index in 0 to 7 loop
            if th_min_write_onehot(entry) = '1' and
               threshold_write_byte(byte_index) = '1' then
              th_min_buf(entry)((7-byte_index)*8 + 7 downto (7-byte_index)*8) <= threshold_write_data;
            end if;
            if th_max_write_onehot(entry) = '1' and
               threshold_write_byte(byte_index) = '1' then
              th_max_buf(entry)((7-byte_index)*8 + 7 downto (7-byte_index)*8) <= threshold_write_data;
            end if;
          end loop;
        end loop;

        -- Second and third stages of the per-channel read pipeline.
        if rbcp_read_stage1_valid = '1' then
          rbcp_read_word <= rbcp_read_groups(rbcp_read_group_index);
          rbcp_read_byte_stage2 <= rbcp_read_byte_stage1;
          rbcp_read_enable_stage2 <= rbcp_read_enable_stage1;
        end if;
        if rbcp_read_stage2_valid = '1' then
          rbcp_ack <= '1';
          if rbcp_read_enable_stage2 = '1' then
            rbcp_rd(0) <= rbcp_read_word(0);
          else
            rbcp_rd <= rbcp_read_word((7-rbcp_read_byte_stage2)*8 + 7 downto
                                      (7-rbcp_read_byte_stage2)*8);
          end if;
        end if;
        if rbcp_read_busy = '1' and rbcp_read_stage1_valid = '0' and
           rbcp_read_stage2_valid = '0' and rbcp_re_dec = '0' then
          rbcp_read_busy <= '0';
        end if;

        if sel_ctl_reg = '1' then
            if rbcp_we_dec = '1' then
              rbcp_ack <= '1';
              if rbcp_wd_dec(0) = '0' then
                sft_rst <= '1';
              else
                en_trig <= '1';
              end if;
            elsif rbcp_re_dec = '1' then
              rbcp_ack <= '1';
              rbcp_rd(0) <= enable;
            end if;

        elsif sel_trig_pos_reg = '1' then
            if int_byte_dec < 2 then
              if rbcp_we_dec = '1' then
                rbcp_ack <= '1';
                trig_pos((1-int_byte_dec)*8 + 7 downto (1-int_byte_dec)*8) <= rbcp_wd_dec;
              elsif rbcp_re_dec = '1' then
                rbcp_ack <= '1';
                rbcp_rd  <= trig_pos((1-int_byte_dec)*8 + 7 downto (1-int_byte_dec)*8);
              end if;
            end if;

        elsif sel_thre_cnt_reg = '1' then
            if int_byte_dec < 2 then
              if rbcp_we_dec = '1' then
                rbcp_ack <= '1';
                thre_cnt((1-int_byte_dec)*8 + 7 downto (1-int_byte_dec)*8) <= rbcp_wd_dec;
              elsif rbcp_re_dec = '1' then
                rbcp_ack <= '1';
                rbcp_rd  <= thre_cnt((1-int_byte_dec)*8 + 7 downto (1-int_byte_dec)*8);
              end if;
            end if;

        elsif sel_enable_reg = '1' or
              sel_th_min_a_reg = '1' or
              sel_th_min_b_reg = '1' or
              sel_th_max_a_reg = '1' or
              sel_th_max_b_reg = '1' then
          if int_ch_dec < N_CH_TRIG then

            if sel_enable_reg = '1' then
              if rbcp_we_dec = '1' then
                rbcp_ack <= '1';
                ch_enable_write_onehot(int_ch_dec*2+0) <= '1';
                ch_enable_write_onehot(int_ch_dec*2+1) <= '1';
                ch_enable_write_data <= rbcp_wd_dec(0);
              end if;
            end if;

            if sel_th_min_a_reg = '1' then
              if int_byte_dec < 8 then
                if rbcp_we_dec = '1' then
                  rbcp_ack <= '1';
                  th_min_write_onehot(int_ch_dec*2+0) <= '1';
                  threshold_write_byte(int_byte_dec) <= '1';
                  threshold_write_data <= rbcp_wd_dec;
                end if;
              end if;

            elsif sel_th_min_b_reg = '1' then
              if int_byte_dec < 8 then
                if rbcp_we_dec = '1' then
                  rbcp_ack <= '1';
                  th_min_write_onehot(int_ch_dec*2+1) <= '1';
                  threshold_write_byte(int_byte_dec) <= '1';
                  threshold_write_data <= rbcp_wd_dec;
                end if;
              end if;

            elsif sel_th_max_a_reg = '1' then
              if int_byte_dec < 8 then
                if rbcp_we_dec = '1' then
                  rbcp_ack <= '1';
                  th_max_write_onehot(int_ch_dec*2+0) <= '1';
                  threshold_write_byte(int_byte_dec) <= '1';
                  threshold_write_data <= rbcp_wd_dec;
                end if;
              end if;

            elsif sel_th_max_b_reg = '1' then
              if int_byte_dec < 8 then
                if rbcp_we_dec = '1' then
                  rbcp_ack <= '1';
                  th_max_write_onehot(int_ch_dec*2+1) <= '1';
                  threshold_write_byte(int_byte_dec) <= '1';
                  threshold_write_data <= rbcp_wd_dec;
                end if;
              end if;

            end if;

            -- First read stage: select one of eight entries independently in
            -- every group.  The following cycles select the group and byte.
            if rbcp_re_dec = '1' and rbcp_read_busy = '0' and
               (sel_enable_reg = '1' or int_byte_dec < 8) then
              entry_index := int_ch_dec*2;
              if sel_th_min_b_reg = '1' or sel_th_max_b_reg = '1' then
                entry_index := entry_index + 1;
              end if;
              lane_index := entry_index mod RBCP_MUX_GROUP_SIZE;
              rbcp_read_group_index <= entry_index / RBCP_MUX_GROUP_SIZE;
              rbcp_read_byte_stage1 <= int_byte_dec mod 8;
              rbcp_read_enable_stage1 <= sel_enable_reg;
              rbcp_read_stage1_valid <= '1';
              rbcp_read_busy <= '1';

              for grp in 0 to N_RBCP_MUX_GROUP-1 loop
                if sel_enable_reg = '1' then
                  rbcp_read_groups(grp) <= (others => '0');
                  rbcp_read_groups(grp)(0) <= ch_enable(grp*RBCP_MUX_GROUP_SIZE + lane_index);
                elsif sel_th_min_a_reg = '1' or sel_th_min_b_reg = '1' then
                  rbcp_read_groups(grp) <= th_min_buf(grp*RBCP_MUX_GROUP_SIZE + lane_index);
                else
                  rbcp_read_groups(grp) <= th_max_buf(grp*RBCP_MUX_GROUP_SIZE + lane_index);
                end if;
              end loop;
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
