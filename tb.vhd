library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.Types.all;

entity tb is 
end entity;

architecture rtl of tb is
  signal RstN     : bit1;
  signal Clk50MHz : bit1;
  signal PS2Data : bit1;
  signal PS2Clk  : bit1;
begin
  RstN <= '0', '1' after 100 ns;
  
  ClkGen : process
  begin
    while true loop
      Clk50MHz <= '0';
      wait for 10 ns;
      Clk50MHz <= '1';
      wait for 10 ns;
    end loop;
  end process;

  DUT : entity work.PS2Top
    port map (
      AsyncRst => RstN,
      Clk      => Clk50MHz,
      --
      PS2Data  => PS2Data,
      PS2Clk   => PS2Clk,
      --
      SerialOut => open,
      SerialIn => '0'
      );  
  
end architecture rtl;
