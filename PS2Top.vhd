-- Top entity for the PS2 Test
-- Copyright Erik Zachrisson 2014

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.Types.all;
use work.SerialPack.all;
use work.PS2Pack.all;

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
  signal Rst_N              : bit1;
  signal Packet             : word(8-1 downto 0);
  signal PacketVal          : bit1;
  signal Clk25MHz           : bit1;
  signal Clk64kHz           : bit1;

  signal RegAccessToPS2, RegAccessFromPS2, RegAccessFromFifo, RegAccess : RegAccessRec;
  
begin
  Pll25MHz : entity work.PLL
    port map (
      inclk0 => Clk,
      c0     => Clk25MHz
      );

  Clk64kHzGen : entity work.ClkDiv
    generic map (
      SourceFreq => Clk25MHz_integer,
      SinkFreq   => 32000
      )
    port map (
      Clk     => Clk,
      RstN    => Rst_N,
      Clk_out => Clk64khz
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
    constant FifoSize : positive := 128;
    constant FifoSizeW : positive := bits(FifoSize);
    --
    signal Baud                                                 : word(3-1 downto 0);
    signal SerDataFromFifo                                      : word(8-1 downto 0);
    signal SerDataToFifo                                        : word(8-1 downto 0);
    signal SerDataRd, SerDataFifoEmpty, SerDataWr, SerWriteBusy : bit1;
    signal Busy                                                 : bit1;
    --
    signal IncSerChar                                           : word(8-1 downto 0);
    signal IncSerCharVal                                        : bit1;
    signal Level                                                : word(FifoSizeW-1 downto 0);
    signal MaxFillLevel_N, MaxFillLevel_D                       : word(FifoSizeW-1 downto 0);
    --
    
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
         RegAccessOut   => RegAccessToPs2,
         RegAccessIn    => RegAccess,
         --
         OutSerCharBusy => Busy,
         OutSerChar     => SerDataToFifo,
         OutSerCharVal  => SerDataWr
         );

    RegAccess.Val  <= RegAccessFromPS2.Val or RegAccessFromFifo.Val;
    RegAccess.Data <= RegAccessFromPS2.Data or RegAccessFromFifo.Data;
    RegAccess.Addr <= RegAccessFromPS2.Addr or RegAccessFromFifo.Addr;
    RegAccess.Cmd  <= RegAccessFromPS2.Cmd or RegAccessFromFifo.Cmd;
    
    SerOutFifo : entity work.SerialOutFifo
      port map (
        clock => Clk25MHz,
        data  => SerDataToFifo,
        wrreq => SerDataWr,
        full  => Busy,
        --
        usedw => Level,
        --
        rdreq => SerDataRd,
        q     => SerDataFromFifo,
        empty => SerDataFifoEmpty
        );
    SerDataRd <= '1' when SerDataFifoEmpty = '0' and SerWriteBusy = '0' else '0';

    AsyncProc : process (Level, MaxFillLevel_D, RegAccessToPS2)
    begin
      MaxFillLevel_N <= MaxFillLevel_D;
      RegAccessFromFifo <= Z_RegAccessRec;
      
      if Level > MaxFillLevel_D then
        MaxFillLevel_N <= Level;
      end if;

      if RegAccessToPs2.Val = "1" then
        if RegAccessToPs2.Cmd = REG_READ then
          if RegAccessToPs2.Addr = SerFifoLvl then
            RegAccessFromFifo.Data(FifoSizeW-1 downto 0) <= Level;
          elsif RegAccessToPs2.Addr = SerFifoMaxLvl then
            RegAccessFromFifo.Data(FifoSizeW-1 downto 0) <= MaxFillLevel_D;
            MaxFillLevel_N                   <= (others => '0');
          end if;
        end if;
      end if;      
    end process;

    SyncProc : process (Clk25MHz, Rst_N)
    begin
      if Rst_N = '0' then
        MaxFillLevel_D <= (others => '0');
      elsif rising_edge(Clk25MHz) then
        MaxFillLevel_D <= MaxFillLevel_N;
      end if;
    end process;

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

  -- Mouse decoding
  -- Servo
  
  
  
end architecture rtl;
