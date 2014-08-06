library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.Types.all;

entity PS2Top is
        port (
        AsyncRst : in bit1;
        Clk      : in bit1;
        --
        PS2Data  : inout bit1;
        PS2Clk   : inout bit1
        --
        
        );
end entity;

architecture rtl of PS2Top is
  signal Rst_N     : bit1;
  signal Packet    : word(8-1 downto 0);
  signal PacketVal : bit1;
  signal Clk25MHz  : bit1;
  
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
    port map (
      Clk       => Clk25MHz,
      Rst_N     => Rst_N,
      --
      PS2Clk    => PS2Clk,
      PS2Data   => PS2Data,
      --
      Packet    => Packet,
      PacketVal => PacketVal
      );

  Serial : block
    signal OutSerCharVal, IncSerCharVal : bit1;
    signal OutSerCharBusy               : bit1;
    signal OutSerChar, IncSerChar       : word(Byte-1 downto 0);
    --
    signal Baud                         : word(3-1 downto 0);
  begin
    Baud <= "010";

    SerRead : entity work.SerialReader
      generic map (
        DataW   => 8,
        ClkFreq => Clk25MHz_integer
        )
      port map (
        Clk   => Clk25MHz,
        RstN  => RstN25MHz,
        --
        Rx    => SerialIn,
        --
        Baud  => Baud,
        --
        Dout  => IncSerChar,
        RxRdy => IncSerCharVal
        );
    
    SerWrite : entity work.SerialWriter
      generic map (
        ClkFreq => Clk25MHz_integer
        )
      port map (
        Clk       => Clk25MHz,
        Rst_N     => RstN25MHz,
        --
        Baud      => Baud,
        --
        We        => OutSerCharVal,
        WData     => OutSerChar,
        --
        Busy      => OutSerCharBusy,
        SerialOut => SerialOut
        );

    RegAccessOut.Val  <= RegAccessOutSccb.Val or RegAccessOutRespHdler.Val;
    RegAccessOut.Data <= RegAccessOutSccb.Data or RegAccessOutRespHdler.Data;
    RegAccessOut.Cmd  <= RegAccessOutSccb.Cmd;
    RegAccessOut.Addr <= RegAccessOutSccb.Addr;

    SerCmdParser : entity work.SerialCmdParser
      port map (
        RstN           => RstN25MHz,
        Clk            => Clk25MHz,
        --
        IncSerChar     => IncSerChar,
        IncSerCharVal  => IncSerCharVal,
        --
        OutSerCharBusy => OutSerCharBusy,
        OutSerChar     => OutSerChar,
        OutSerCharVal  => OutSerCharVal,
        RegAccessOut   => RegAccessIn,
        RegAccessIn    => RegAccessOut
        );
  end block;  
end architecture rtl;
