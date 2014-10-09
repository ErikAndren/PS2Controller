library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.Types.all;

entity MouseStateTracker is
  generic (
    DataW   : positive := 8;
    PwmResW : positive := 7
    );
  port (
    Clk         : in  bit1;
    RstN        : in  bit1;
    --
    Packet      : in  word(DataW-1 downto 0);
    PacketInVal : in  bit1;
    --
    PwmXPos     : out word(PwmResW-1 downto 0);
    PwmYPos     : out word(PwmResW-1 downto 0)
    );
end entity;

architecture rtl of MouseStateTracker is
  constant MouseResW                                        : positive := 10;
  --
  signal MouseXPos_N, MouseXPos_D, MouseYPos_N, MouseYPos_D : word(MouseResW-1 downto 0);
  --
  signal PacketCnt_N, PacketCnt_D                           : word(2-1 downto 0);
  signal TempXPos_N, TempXPos_D                             : word(2-1 downto 0);
  signal TempYPos_N, TempYPos_D                             : word(2-1 downto 0);
  
begin
  SyncProc : process (Clk, RstN)
  begin
    if RstN = '0' then
      PacketCnt_D                   <= (others => '0');
      --
      MouseXPos_D                   <= (others => '0');
      MouseXPos_D(MouseXPos_D'high) <= '1';
      --
      MouseYPos_D                   <= (others => '0');
      MouseYPos_D(MouseYPos_D'high) <= '1';
      --
      TempXPos_D                    <= (others => '0');
      TempYPos_D                    <= (others => '0');
    elsif rising_edge(Clk) then
      PacketCnt_D <= PacketCnt_N;
      MouseXPos_D <= MouseXPos_N;
      MouseYPos_D <= MouseYPos_N;
      TempXPos_D  <= TempXPos_N;
      TempYPos_D  <= TempYPos_N;
    end if;
  end process;

  ASyncProc : process (Packet, PacketInVal, MouseXPos_D, MouseYPos_D, TempXPos_D, TempYPos_D, PacketCnt_D)
    constant XOverflowBit : positive := 6;
    constant YOverflowBit : positive := 7;
    --
    constant XSignBit     : positive := 4;
    constant YSignBit     : positive := 5;
    --
    constant SignBit      : natural  := 1;
    constant OverflowBit  : natural  := 0;
    --
    constant Pos          : bit1     := '0';
    constant Neg          : bit1     := '1';
  begin
    PacketCnt_N <= PacketCnt_D;
    MouseXPos_N <= MouseXPos_D;
    MouseYPos_N <= MouseYPos_D;
    TempXPos_N  <= TempXPos_D;
    TempYPos_N  <= TempYPos_D;
    
    if PacketInVal = '1' then
      if PacketCnt_D = 0 then
        TempXPos_N(SignBit)     <= Packet(XSignBit);
        TempXPos_N(OverflowBit) <= Packet(XOverflowBit);
        TempYPos_N(SignBit)     <= Packet(YSignBit);
        TempYPos_N(OverflowBit) <= Packet(YOverflowBit);
        --
        PacketCnt_N             <= "01";
        
      elsif PacketCnt_D = 1 then
        PacketCnt_N <= "10";

        -- Left is pos, Right is neg
        -- Decode X
        if TempXPos_D(OverflowBit) = '1' then
          if TempXPos_D(SignBit) = Pos then
            MouseXPos_N <= (others => '1');
          else
            MouseXPos_N <= (others => '0');
          end if;
        else
          if TempXPos_D(SignBit) = Pos then
            if MouseXPos_D + Packet <= xt1(MouseResW) then
              MouseXPos_N <= MouseXPos_D + Packet;
            else
              MouseXPos_N <= (others => '1');
            end if;
          else
            if MouseXPos_D - Packet >= xt0(MouseResW) then
              MouseXPos_N <= MouseXPos_D - Packet;
            else
              MouseXPos_N <= (others => '0');
            end if;
          end if;
        end if;
        
      elsif PacketCnt_D = 2 then
        PacketCnt_N              <= "00";

        -- Decode X
        if TempYPos_D(OverflowBit) = '1' then
          if TempYPos_D(SignBit) = Pos then
            MouseYPos_N <= (others => '1');
          else
            MouseYPos_N <= (others => '0');
          end if;
        else
          if TempYPos_D(SignBit) = Pos then
            if MouseYPos_D + Packet <= xt1(MouseResW) then
              MouseYPos_N <= MouseYPos_D + Packet;
            else
              MouseYPos_N <= (others => '1');
            end if;
          else
            if MouseYPos_D - ((not Packet) + 1) >= xt0(MouseResW) then
              -- 2 comp conversion
              MouseYPos_N <= MouseYPos_D - ((not Packet) + 1);
            else
              MouseYPos_N <= (others => '0');
            end if;
          end if;
        end if;
      end if;
    end if;
  end process;

  -- Extract MSBs
  PwmXPos      <= MouseXPos_D(MouseResW-1 downto MouseResW - PwmResW);
  PwmYPos      <= MouseYPos_D(MouseResW-1 downto MouseResW - PwmResW);
end architecture rtl;
