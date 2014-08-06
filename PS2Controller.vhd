library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.Types.all;

entity PS2Controller is
  port (
    Clk       : in    bit1;
    Rst_N     : in    bit1;
    --
    PS2Clk    : inout bit1;
    PS2Data   : inout bit1;
    --
    Packet    : out   word(8-1 downto 0);
    PacketVal : out   bit1
    );
end entity;

architecture rtl of PS2Controller is
  signal PS2Sampler_D, PS2Sampler_N : word(11-1 downto 0);
  signal SampledData                 : word(8-1 downto 0);
  --
  signal PS2Cnt_D, PS2Cnt_N          : word(4-1 downto 0);
  signal PS2We                       : bit1;
  --
  signal PS2Clk_D                    : bit1;
begin
  PS2Sync : process (Rst_N, Clk)
  begin
    if Rst_N = '0' then
      PS2Clk_D     <= '0';
      PS2Sampler_D <= (others => '0');
      PS2Cnt_D     <= (others => '0');
    elsif rising_edge(Clk) then
      PS2Clk_D     <= PS2Clk;
      PS2Sampler_D <= PS2Sampler_N;
      PS2Cnt_D     <= PS2Cnt_N;
    end if;
  end process;

  PS2ASync : process (PS2Clk, PS2Clk_D, PS2Data, PS2Sampler_D, PS2Cnt_D)
  begin
    PS2Sampler_N <= PS2Sampler_D;
    PS2Cnt_N     <= PS2Cnt_D;

    if PS2Clk_D = '1' and PS2Clk = '0' then
      PS2Sampler_N <= PS2Data & PS2Sampler_D(10 downto 1);
      PS2Cnt_N     <= PS2Cnt_D + 1;
    end if;

    if PS2Cnt_D = 11 then
      PS2Cnt_N <= (others => '0');
    end if;
  end process;

  Packet    <= PS2Sampler_D(8 downto 1);
  PacketVal <= '1' when (PS2Cnt_D = 11) and (ParityErr(PS2Sampler_D(9 downto 1)) = '1') else '0';
end architecture rtl;
