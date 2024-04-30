library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_ARITH.all;
use IEEE.STD_LOGIC_SIGNED.all;

library work;
use work.rhea_pkg.all;

entity phy_speed_checker is
  port(
    clk    : in  std_logic;
    rst    : in  std_logic;
    rxclk  : in  std_logic;
    --rxspan : out std_logic_vector(7 downto 0);
    is1000 : out std_logic);
end phy_speed_checker;

architecture Behavioral of phy_speed_checker is

  type state is (idle, cnt);
  signal st_r : state;

  signal rxspan_buf : std_logic_vector( 7 downto 0);
  signal spd_judge  : std_logic_vector(15 downto 0);

begin

  process(clk)
  begin
    if rising_edge(clk) then
      is1000 <= spd_judge(15);
    end if;
  end process;

  process(clk)
  begin
    if rising_edge(clk) then
      case st_r is
        when idle =>
          if rxclk = '0' then
            st_r <= cnt;
            rxspan_buf <= (others => '0');
          end if;

        when cnt =>
          --if rxclk = '1' or rxspan_buf = (rxspan_buf'range => '1') then
          if rxclk = '1' then
            st_r <= idle;
            --rxspan <= rxspan_buf;
            if rxspan_buf < x"02" then
              if spd_judge /= (spd_judge'range => '1') then
                spd_judge <= spd_judge + '1';
              end if;
            else
              if spd_judge /= (spd_judge'range => '0') then
                spd_judge <= spd_judge - '1';
              end if;
            end if;
          else
            if rxspan_buf /= (rxspan_buf'range => '1') then
              rxspan_buf <= rxspan_buf + '1';
            end if;
          end if;

        when others => null;

      end case;
      if rst = '1' then
        st_r <= idle;
        spd_judge  <= (others => '0');
        --rxspan     <= (others => '0');
        rxspan_buf <= (others => '0');
      end if;
    end if;
  end process;

end Behavioral;
