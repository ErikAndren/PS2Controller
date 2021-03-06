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
    AsyncRst   : in    bit1;
    Clk        : in    bit1;
    --
    PS2Data    : inout bit1;
    PS2Clk     : inout bit1;
    --
    SerialIn   : in    bit1;
    SerialOut  : out   bit1;
    --
    YawServo   : out   bit1;
    PitchServo : out   bit1
    );
end entity;

architecture rtl of PS2Top is
  constant ServoResW                                                    : positive := 8;
  --
  constant Clk25MHz_integer                                             : positive := 25000000;
  --
  signal Rst_N                                                          : bit1;
  signal Ps2DevResp                                                     : word(8-1 downto 0);
  signal Ps2DevRespVal                                                  : bit1;
  signal Ps2HostCmd                                                     : word(8-1 downto 0);
  signal Ps2HostCmdVal                                                  : bit1;
  signal Clk25MHz                                                       : bit1;
  signal Clk64kHz                                                       : bit1;
  signal PS2IsStreaming                                                 : bit1;
  --
  signal PitchPos, YawPos                                               : word(ServoResW-1 downto 0);
  --
  signal RegAccessFromMouseTracker, RegAccessFromPs2Init, RegAccessToPS2, RegAccessFromPS2, RegAccessFromFifo, RegAccess : RegAccessRec;
  
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
      Clk     => Clk25MHz,
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

  PS2Initer : entity work.PS2Init
    port map (
      Clk           => Clk25MHz,
      Rst_N         => Rst_N,
      --
      PS2HostCmd    => Ps2HostCmd,
      PS2HostCmdVal => Ps2HostCmdVal,
      --
      PS2DevResp    => Ps2DevResp,
      PS2DevRespVal => Ps2DevRespVal,
      --
      Streaming     => PS2IsStreaming,
      --
      RegAccessIn =>  RegAccessToPS2,
      RegAccessOut => RegAccessFromPs2Init
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
      Packet       => Ps2DevResp,
      PacketVal    => Ps2DevRespVal,
      --
      ToPs2Data    => Ps2HostCmd,
      ToPs2Val     => Ps2HostCmdVal,
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

    RegAccess.Val  <= RegAccessFromPS2.Val or RegAccessFromFifo.Val or RegAccessFromPs2Init.Val or RegAccessFromMouseTracker.Val;
    RegAccess.Data <= RegAccessFromPS2.Data or RegAccessFromFifo.Data or RegAccessFromPs2Init.Data or RegAccessFromMouseTracker.Data;
    RegAccess.Addr <= RegAccessFromPS2.Addr or RegAccessFromFifo.Addr or RegAccessFromPs2Init.Addr or RegAccessFromMouseTracker.Addr;
    RegAccess.Cmd  <= RegAccessFromPS2.Cmd or RegAccessFromFifo.Cmd or RegAccessFromPs2Init.Cmd or RegAccessFromMouseTracker.Cmd;
    
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

  MouseStateTrack : entity work.MouseStateTracker
    generic map (
      PwmResW => ServoResW
      )
    port map (
      Clk          => Clk25MHz,
      RstN         => Rst_N,
      --
      Streaming    => PS2IsStreaming,
      --
      Packet       => Ps2DevResp,
      PacketInVal  => Ps2DevRespVal,
      --
      PwmXPos      => YawPos,
      PwmYPos      => PitchPos,
      --
      RegAccessIn  => RegAccessToPs2,
      RegAccessOut => RegAccessFromMouseTracker
      );
  
  YawServoDriver : entity work.ServoPwm
    generic map (
      ResW => ServoResW
      )
    port map (
      Clk   => Clk64Khz,
      RstN  => Rst_N,
      --
      Pos   => YawPos,
      --
      Servo => YawServo
      );

  PitchServoDriver : entity work.ServoPwm
    generic map (
      ResW => ServoResW
      )
    port map (
      Clk   => Clk64Khz,
      RstN  => Rst_N,
      --
      Pos   => PitchPos,
      --
      Servo => PitchServo
      );  
end architecture rtl;
