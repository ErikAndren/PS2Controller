--
-- PS2 Controller
-- Implements a state machine capable of send and receiving data to a PS2 device
--
-- Copyright: Erik Zachrisson erik@zachrisson.info 2014
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.Types.all;
use work.PS2Pack.all;
use work.SerialPack.all;

entity PS2Controller is
  generic (
    DataW      : positive := 8;
    ClkFreq    : positive;
    PS2ClkFreq : positive := 10000
    );
  port (
    Clk          : in    bit1;
    Rst_N        : in    bit1;
    -- Outgoing Clk 10 - 16 KHz 
    PS2Clk       : inout bit1;
    PS2Data      : inout bit1;
    --
    ToPs2Data    : in    word(DataW-1 downto 0);
    ToPs2Val     : in    bit1;
    --
    Packet       : out   word(DataW-1 downto 0);
    PacketVal    : out   bit1;
    --
    RegAccessIn  : in    RegAccessRec;
    RegAccessOut : out   RegAccessRec
    );
end entity;

architecture rtl of PS2Controller is
  signal PS2Sampler_D, PS2Sampler_N : word(DataW downto 0);
  signal PS2State_N, PS2State_D     : word(6-1 downto 0);
  --
  constant ClkToPS2ClkRatio         : positive := ClkFreq / PS2ClkFreq;
  signal ClkCnt_N, ClkCnt_D         : integer;
  signal Packet_i                   : word(DataW-1 downto 0);
  signal PacketVal_i                : bit1;
  --
  signal ToPs2Val_i                 : bit1;
  signal ToPs2Data_i                : word(DataW-1 downto 0);
  --
  signal PS2Data_D : bit1;
  signal PS2Clk_D : bit1;

  function toZ(input : bit1) return bit1 is
  begin
    if input = '1' then
      return 'Z';
    end if;
    return '0';
  end function;
  
begin
  RegAccessCtrl : process (RegAccessIn, Packet_i, PacketVal_i, ToPS2Val, ToPS2Data, PS2State_D, PS2Sampler_D)
  begin
    ToPs2Val_i  <= ToPs2Val;
    ToPs2Data_i <= ToPs2Data;
    
    RegAccessOut <= Z_RegAccessRec;
    
    if PacketVal_i = '1' then
      RegAccessOut.Val                    <= "1";
      RegAccessOut.Cmd                    <= conv_word(REG_READ, RegAccessOut.Cmd'length);
      RegAccessOut.Data(DataW-1 downto 0) <= Packet_i;
    end if;

    if ToPs2Val = '1' then
      RegAccessOut.Val <= "1";
      RegAccessOut.Cmd <= conv_word(REG_WRITE, RegAccessOut.Cmd'length);
      RegAccessOut.Data(ToPs2Data'length-1 downto 0) <= ToPS2Data;
    end if;
    
    if RegAccessIn.Val = "1" then
      -- Loopback
      RegAccessOut <= RegAccessIn;

      if RegAccessIn.Cmd = REG_WRITE then
        -- Write commands
        if RegAccessIn.Addr = PS2Addr then
          ToPs2Val_i  <= '1';
          ToPs2Data_i <= RegAccessIn.Data(DataW-1 downto 0);
        end if;
      else
        -- Read commands
        if RegAccessIn.Addr = PS2State then
          RegAccessOut.Data(PS2State_D'length-1 downto 0) <= PS2State_D;
        end if;

        if RegAccessIn.Addr = PS2Sampler then
          RegAccessOut.Data(PS2Sampler_D'length-1 downto 0) <= PS2Sampler_D;
        end if;      
      end if;
    end if;
  end process;
      
  PS2Sync : process (Rst_N, Clk)
  begin
    if Rst_N = '0' then
      PS2Sampler_D <= (others => '0');
      ClkCnt_D     <= 0;
      PS2State_D   <= (others => '0');
      PS2Data_D <= '0';
      PS2Clk_D <= '0';
      
    elsif rising_edge(Clk) then
      PS2Sampler_D <= PS2Sampler_N;
      PS2State_D   <= PS2State_N;
      ClkCnt_D     <= ClkCnt_N;
      PS2Clk_D     <= PS2Clk;
      PS2Data_D    <= PS2Data;
    end if;
  end process;

  PS2ASync : process (PS2Sampler_D, ClkCnt_D, PS2State_D, ToPs2Val_i, ToPs2Data_i, PS2Data_D, PS2Clk_D)
  begin
    PacketVal_i  <= '0';
    PS2Sampler_N <= PS2Sampler_D;

    PS2Clk  <= 'Z';
    PS2Data <= 'Z';

    ClkCnt_N <= ClkCnt_D - 1;
    -- Terminate on zero
    if ClkCnt_D = 0 then
      ClkCnt_N <= 0;
    end if;
    
    PS2State_N <= PS2State_D;
    -- Advance state if counter soon is 0
    if ClkCnt_D = 1 then
      PS2State_N <= PS2State_D + 1;
    end if;

    case conv_integer(PS2State_D) is
      -- Send procedure
      when 1 =>
        -- Wait for at least 100 us = at least two PS2Clk cycles @ 16 KHz
        PS2Clk <= '0';

        -- Set timer
        if ClkCnt_D = 0 then
          ClkCnt_N <= 4 * ClkToPS2ClkRatio;
        end if;
                
      when 2 =>
        -- Send start bit
        -- Request to send
        PS2Data    <= '0';
        PS2Clk     <= '0';
        PS2State_N <= conv_word(3, PS2State_N'length);
        
      when 3 =>
        PS2Data <= '0';
        PS2Clk  <= '0';
        if ClkCnt_D = 0 then
          ClkCnt_N <= ClkToPS2ClkRatio;
        end if;

      when 4 =>
        -- Release clk line
        PS2Data <= '0';
        if ClkCnt_D = 0 then
          ClkCnt_N <= ClkToPS2ClkRatio;
        end if;

      when 5 =>
        PS2Data <= '0';
        if PS2Clk_D = '0' then
          PS2State_N <= conv_word(6, PS2State_D'length);
        end if;
        
      when 6 =>
        PS2Data <= toZ(PS2Sampler_D(0));
        if PS2Clk_D = '1' then
          PS2State_N <= conv_word(7, PS2State_D'length);         
        end if;

      when 7 =>
        PS2Data <= toZ(PS2Sampler_D(0));
        if PS2Clk_D = '0' then
          PS2State_N <= conv_word(8, PS2State_D'length);         
        end if;
        
      when 8 =>
        PS2Data <= toZ(PS2Sampler_D(1));
        if PS2Clk_D = '1' then
          PS2State_N <= conv_word(9, PS2State_D'length);         
        end if;

      when 9 =>
        PS2Data <= toZ(PS2Sampler_D(1));
        if PS2Clk_D = '0' then
          PS2State_N <= conv_word(10, PS2State_D'length);         
        end if;

      when 10 =>
        PS2Data <= toZ(PS2Sampler_D(2));
        if PS2Clk_D = '1' then
          PS2State_N <= conv_word(11, PS2State_D'length);         
        end if;

      when 11 =>
        PS2Data <= toZ(PS2Sampler_D(2));
        if PS2Clk_D = '0' then
          PS2State_N <= conv_word(12, PS2State_D'length);         
        end if;

      when 12 =>
        PS2Data <= toZ(PS2Sampler_D(3));
        if PS2Clk_D = '1' then
          PS2State_N <= conv_word(13, PS2State_D'length);         
        end if;

      when 13 =>
        PS2Data <= toZ(PS2Sampler_D(3));
        if PS2Clk_D = '0' then
          PS2State_N <= conv_word(14, PS2State_D'length);         
        end if;

      when 14 =>
        PS2Data <= toZ(PS2Sampler_D(4));
        if PS2Clk_D = '1' then
          PS2State_N <= conv_word(15, PS2State_D'length);         
        end if;

      when 15 =>
        PS2Data <= toZ(PS2Sampler_D(4));
        if PS2Clk_D = '0' then
          PS2State_N <= conv_word(16, PS2State_D'length);         
        end if;
        
      when 16 =>
        PS2Data <= toZ(PS2Sampler_D(5));
        if PS2Clk_D = '1' then
          PS2State_N <= conv_word(17, PS2State_D'length);         
        end if;

      when 17 =>
        PS2Data <= toZ(PS2Sampler_D(5));
        if PS2Clk_D = '0' then
          PS2State_N <= conv_word(18, PS2State_D'length);         
        end if;

      when 18 =>
        PS2Data <= toZ(PS2Sampler_D(6));
        if PS2Clk_D = '1' then
          PS2State_N <= conv_word(19, PS2State_D'length);         
        end if;

      when 19 =>
        PS2Data <= toZ(PS2Sampler_D(6));
        if PS2Clk_D = '0' then
          PS2State_N <= conv_word(20, PS2State_D'length);         
        end if;

      when 20 =>
        PS2Data <= toZ(PS2Sampler_D(7));
        if PS2Clk_D = '1' then
          PS2State_N <= conv_word(21, PS2State_D'length);         
        end if;

      when 21 =>
        PS2Data <= toZ(PS2Sampler_D(7));
        if PS2Clk_D = '0' then
          PS2State_N <= conv_word(22, PS2State_D'length);         
        end if;
        
      when 22 =>
        -- Calc odd parity
        PS2Data <= toZ(MakeParityBit(PS2Sampler_D(8-1 downto 0)));
        if PS2Clk_D = '1' then
          PS2State_N <= conv_word(23, PS2State_D'length);         
        end if;
                                 
      when 23 =>
        -- Calc odd parity
        PS2Data <= toZ(MakeParityBit(PS2Sampler_D(8-1 downto 0)));
        if PS2Clk_D = '0' then
          PS2State_N <= conv_word(24, PS2State_D'length);         
        end if;

      when 24 =>
        -- Release data line and wait for that the device brings data low
        if PS2Data_D = '0' then
          PS2State_N <= conv_word(25, PS2State_D'length);
        end if;

      when 25 =>
        -- Wait for clock low
        if PS2Clk_D = '0' then
          PS2State_N <= conv_word(26, PS2State_D'length);
        end if;

      when 26 =>
        if PS2Clk_D = '1' and PS2Data_D = '1' then
          PS2State_N <= conv_word(0, PS2State_D'length);

          -- Return to idle
          PS2State_N <= (others => '0');
        end if;

      -- Start of device to host transaction
      when 27 =>
        if PS2Clk_D = '1' then
          PS2State_N <= conv_word(28, PS2State_D'length);
        end if;

      when 28 =>
        if PS2Clk_D = '0' then
          PS2Sampler_N(0) <= PS2Data_D;
          PS2State_N <= conv_word(29, PS2State_D'length);
        end if;

      when 29 =>
        if PS2Clk_D = '1' then
          PS2State_N <= conv_word(30, PS2State_D'length);
        end if;

      when 30 => 
        if PS2Clk_D = '0' then
          PS2Sampler_N(1) <= PS2Data_D;
          PS2State_N <= conv_word(31, PS2State_D'length);
        end if;
          
      when 31 =>
        if PS2Clk_D = '1' then
          PS2State_N <= conv_word(32, PS2State_D'length);
        end if;

      when 32 => 
        if PS2Clk_D = '0' then
          PS2Sampler_N(2) <= PS2Data_D;
          PS2State_N <= conv_word(33, PS2State_D'length);
        end if;

      when 33 =>
        if PS2Clk_D = '1' then
          PS2State_N <= conv_word(34, PS2State_D'length);
        end if;

      when 34 => 
        if PS2Clk_D = '0' then
          PS2Sampler_N(3) <= PS2Data_D;
          PS2State_N <= conv_word(35, PS2State_D'length);
        end if;

      when 35 =>
        if PS2Clk_D = '1' then
          PS2State_N <= conv_word(36, PS2State_D'length);
        end if;

      when 36 => 
        if PS2Clk_D = '0' then
          PS2Sampler_N(4) <= PS2Data_D;
          PS2State_N <= conv_word(37, PS2State_D'length);
        end if;

      when 37 =>
        if PS2Clk_D = '1' then
          PS2State_N <= conv_word(38, PS2State_D'length);
        end if;

      when 38 => 
        if PS2Clk_D = '0' then
          PS2Sampler_N(5) <= PS2Data_D;
          PS2State_N <= conv_word(39, PS2State_D'length);
        end if;

      when 39 =>
        if PS2Clk_D = '1' then
          PS2State_N <= conv_word(40, PS2State_D'length);
        end if;

      when 40 => 
        if PS2Clk_D = '0' then
          PS2Sampler_N(6) <= PS2Data_D;
          PS2State_N <= conv_word(41, PS2State_D'length);
        end if;

      when 41 =>
        if PS2Clk_D = '1' then
          PS2State_N <= conv_word(42, PS2State_D'length);
        end if;

      when 42 => 
        if PS2Clk_D = '0' then
          PS2Sampler_N(7) <= PS2Data_D;
          PS2State_N <= conv_word(43, PS2State_D'length);
        end if;

      when 43 =>
        if PS2Clk_D = '1' then
          PS2State_N <= conv_word(44, PS2State_D'length);
        end if;

      when 44 => 
        if PS2Clk_D = '0' then
          -- Parity bit
          PS2Sampler_N(8) <= PS2Data_D;
          PS2State_N <= conv_word(45, PS2State_D'length);
        end if;

      when 45 =>
        if PS2Clk_D = '1' then
          PS2State_N <= conv_word(46, PS2State_D'length);
        end if;

      when 46 => 
        if PS2Clk_D = '0' then
          PS2State_N <= conv_word(0, PS2State_D'length);

          -- Stop bit, must be 1
          if PS2Data_D = '1' then
            -- Evaluate parity
            if (MakeParityBit(PS2Sampler_D(8-1 downto 0)) = PS2Sampler_D(8)) then
              PacketVal_i <= '1';
            end if;
          end if;
        end if;                

      when others =>
        -- Idle, listen for transmission from the device
        if PS2Clk_D = '0' and PS2Data_D = '0' then
          PS2State_N <= conv_word(27, PS2State_N'length);
        end if;
    end case;

    if ToPs2Val_i = '1' then
      -- Jump to send procedure
      PS2State_N                     <= conv_word(1, PS2State_N'length);
      PS2Sampler_N(DataW-1 downto 0) <= ToPs2Data_i;
    end if;
  end process;

  Packet_i  <= PS2Sampler_D(DataW-1 downto 0);
  Packet    <= Packet_i;
  PacketVal <= PacketVal_i;
end architecture rtl;
