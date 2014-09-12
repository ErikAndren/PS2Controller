library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.Types.all;
use work.SerialPack.all;

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

  signal RegAccessToPS2, RegAccessFromPS2 : RegAccessRec;
  
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
      Clk          => Clk25MHz,
      Rst_N        => Rst_N,
      --
      PS2Clk       => PS2Clk,
      PS2Data      => PS2Data,
      --
      Packet       => open,
      PacketVal    => open,
      --
      ToPs2Val     => '0',
      ToPs2Data    => (others => '0'),
      --
      RegAccessIn  => RegAccessToPS2,
      RegAccessOut => RegAccessFromPS2
      );

  Serial : block
    signal Baud                                                 : word(3-1 downto 0);
    signal SerDataRdVal                                         : bit1;
    signal SerDataFromFifo                                      : word(8-1 downto 0);
    signal SerDataToFifo                                        : word(8-1 downto 0);
    signal SerDataRd, SerDataFifoEmpty, SerDataWr, SerWriteBusy : bit1;
    signal SerDataWr_D, SerDataWr_D2                            : bit1;
    signal Busy                                                 : bit1;
    --
    signal IncSerChar                                           : word(8-1 downto 0);
    signal IncSerCharVal                                        : bit1;
  begin
    Baud <= "010";
    
    SerRead : entity work.SerialReader
      generic map (
        DataW   => 8,
        ClkFreq => Clk25MHz_integer
        )
      port map (
        Clk   => Clk25MHz,
        RstN  => Rst_N,
        --
        Rx    => SerialIn,
        --
        Baud  => Baud,
        --
        Dout  => IncSerChar,
        RxRdy => IncSerCharVal
        );
    
     SerCmdParser : entity work.SerialCmdParser
       port map (
         RstN           => Rst_N,
         Clk            => Clk25MHz,
         --
         IncSerChar     => IncSerChar,
         IncSerCharVal  => IncSerCharVal,
         --
         OutSerCharBusy => Busy,
         OutSerChar     => SerDataToFifo,
         OutSerCharVal  => SerDataWr,
         --
         RegAccessOut   => RegAccessToPS2,
         RegAccessIn    => RegAccessFromPS2
       );
    
    SerOutFifo : entity work.SerialOutFifo
      port map (
        clock => Clk25MHz,
        data  => SerDataToFifo,
        wrreq => SerDataWr,
        full  => Busy,
        --
        rdreq => SerDataRd,
        q     => SerDataFromFifo,
        empty => SerDataFifoEmpty
        );
    SerDataRd <= '1' when SerDataFifoEmpty = '0' and SerWriteBusy = '0' else '0';
    
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
        We        => SerDataRd,
        WData     => SerDataFromFifo,
        Busy      => SerWriteBusy,
        --
        SerialOut => SerialOut
        );
  end block;  
end architecture rtl;
