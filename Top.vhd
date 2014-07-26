library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.Types.all;

entity Top is 
	port (
	AsyncRst : in bit1;
	Clk      : in bit1;
        --
        PS2Clk   : inout bit1;
        PS2Data  : inout bit1
	);
end entity;

architecture rtl of Top is
  signal Rst_N : bit1;
  
begin
  RstSync : entity work.ResetSync
    port map (
      AsyncRst => AsyncRst,
      Clk      => Clk,
      --
      Rst_N    => Rst_N
      );
  
  
  
end architecture rtl;
