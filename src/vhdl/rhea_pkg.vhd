-----------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 2015/04/01 22:47:57
-- Design Name: 
-- Module Name: rhea_pkg - Behavioral
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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

package rhea_pkg is

  ---------------------------------------------------------------------------
  -- Global Constants
  ---------------------------------------------------------------------------
  constant RHEA_VERSIONS    : integer := 2022052501; -- YYYYMMDDNN
  constant ENABLE_SNAPSHOT  : integer := 0;
  constant ENABLE_TRIGGER   : integer := 1;
  constant N_CHANNEL_LOG2   : integer := 6;
  constant N_CH_TRIG_LOG2   : integer := 6;
  constant N_CHANNEL_EN     : integer := 64;
  constant N_SUMUP_OFFSET   : integer := 2; -- 0 ~ N_CHANNEL_LOG2XS
  ---
  constant N_CHANNEL        : integer := 2 ** N_CHANNEL_LOG2;
  constant N_CH_TRIG        : integer := (2 ** N_CH_TRIG_LOG2) * ENABLE_TRIGGER;
  constant PHASE_WIDTH      : integer := 32;
  constant SIN_COS_WIDTH    : integer := 16;
  constant ADC_DATA_WIDTH   : integer := 14;
  constant IQ_DATA_WIDTH    : integer := SIN_COS_WIDTH + ADC_DATA_WIDTH + 1;
  constant IQ_DS_DATA_WIDTH : integer := 56;
  constant IQ_PACKET_BYTE   : integer := IQ_DS_DATA_WIDTH/8 * 2 * N_CHANNEL + 7;
  constant DS_RATE_MIN      : integer := 20;
  constant DS_RATE_MAX      : integer := 200000;
  constant DDS_CH_SECTOR    : integer := 1;   -- DDS channel sector
  constant DEBUG_DRIVE_NUM  : integer := 1;
  constant DEBUG_PROBE_NUM  : integer := 2;

  ---------------------------------------------------------------------------
  -- User-difined Data Type
  ---------------------------------------------------------------------------
  subtype byte is std_logic_vector(7 downto 0);
  type byte_array is array (natural range <>) of byte;
  type data_array is array (natural range <>, natural range <>) of std_logic;

  -- ADC
  subtype adc_data is std_logic_vector(ADC_DATA_WIDTH-1 downto 0);
  subtype adc_data_half is std_logic_vector(ADC_DATA_WIDTH/2-1 downto 0);
  type adc_data_array is array (N_CHANNEL-1 downto 0) of adc_data;

  -- DDS
  subtype phase_data is std_logic_vector(PHASE_WIDTH-1 downto 0);
  type phase_array is array (N_CHANNEL-1 downto 0) of phase_data;
  subtype amp_data is std_logic_vector(7 downto 0);
  type amp_array is array (N_CHANNEL-1 downto 0) of amp_data;
  subtype dds_data is std_logic_vector(SIN_COS_WIDTH-1 downto 0);
  type dds_data_array is array (N_CHANNEL-1 downto 0) of dds_data;

  -- DDC
  subtype iq_data is std_logic_vector(IQ_DATA_WIDTH-1 downto 0);
  subtype iq_data_half is std_logic_vector(IQ_DATA_WIDTH-2 downto 0);
  type iq_data_array is array (N_CHANNEL-1 downto 0) of iq_data;

  -- Downsample
  subtype iq_ds_data is std_logic_vector(IQ_DS_DATA_WIDTH-1 downto 0);
  type iq_ds_data_array     is array (N_CHANNEL  -1 downto 0) of iq_ds_data;
  type iq_tri_ds_data_array is array (N_CH_TRIG*2-1 downto 0) of iq_ds_data;

  -- Debug
  type debug_drive_type is array (DEBUG_DRIVE_NUM-1 downto 0) of std_logic_vector(7 downto 0);
  type debug_probe_type is array (DEBUG_PROBE_NUM-1 downto 0) of std_logic_vector(7 downto 0);
  attribute mark_debug : string;
end rhea_pkg;
