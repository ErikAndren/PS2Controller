library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.Types.all;

entity PS2Top is
  port (
    AsyncRst  : in    bit1;
    Clk       : in    bit1;
    --
    PS2Data   : inout bit1;
    PS2Clk    : inout bit1;
    --
    SerialIn  : in    bit1;
    SerialOut : out   bit1
    );
end entity;

architecture rtl of PS2Top is
  constant Clk25MHz_integer : positive := 25000000;
  --
  signal Rst_N     : bit1;
  signal Packet    : word(8-1 downto 0);
  signal PacketVal : bit1;
  signal Clk25MHz  : bit1;

  signal SerData : word(8-1 downto 0);
  signal SerDataVal : bit1;
  
begin
  Pll25MHz : entity work.PLL
    port map (
      inclk0 => Clk,
      c0     => Clk25MHz
      );

  RstSync : entity work.ResetSync
    port map (
      AsyncRst => AsyncRst,
      Clk      => Clk25MHz,
      --
      Rst_N    => Rst_N
      );
  
  PS2Cont : entity work.PS2Controller
    generic map (
      ClkFreq => 25000000
      )
    port map (
      Clk       => Clk25MHz,
      Rst_N     => Rst_N,
      --
      PS2Clk    => PS2Clk,
      PS2Data   => PS2Data,
      --
      Packet    => Packet,
      PacketVal => PacketVal,
      --
      ToPs2Val  => SerDataVal,
      ToPs2Data => SerData
      );

  Serial : block
    signal Baud    : word(3-1 downto 0);
  begin
    Baud <= "010";
    
    SerWrite : entity work.SerialWriter
      generic map (
        ClkFreq => Clk25MHz_integer
        )
      port map (
        Clk       => Clk25MHz,
        Rst_N     => Rst_N,
        --
        Baud      => Baud,
        --
        We        => PacketVal,
        WData     => Packet,
        --
        Busy      => open,
        SerialOut => SerialOut
        );

    SerRead : entity work.SerialReader
      generic map (
        DataW   => 8,
        ClkFreq => Clk25MHz_integer
        )
      port map (
        Clk   => Clk25MHz,
        RstN  => Rst_N,
        Rx    => SerialIn,
        Baud  => Baud,
        --
        Dout  => SerData,
        RxRdy => SerDataVal
        );
    
  end block;  
end architecture rtl;
