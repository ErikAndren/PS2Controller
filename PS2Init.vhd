library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.Types.all;
use work.SerialPack.all;
use work.Ps2Pack.all;

entity PS2Init is
  generic (
    DataW : positive := 8
    );
  port (
    Clk           : in  bit1;
    Rst_N         : in  bit1;
    --
    PS2HostCmd    : out word(DataW-1 downto 0);
    PS2HostCmdVal : out bit1;
    --
    PS2DevResp    : in  word(DataW-1 downto 0);
    PS2DevRespVal : in  bit1;
    --
    Streaming     : out bit1;
    --
    RegAccessIn  : in    RegAccessRec;
    RegAccessOut : out   RegAccessRec
    );
end entity;

architecture rtl of PS2Init is
  signal PS2InitFSM_N, PS2InitFSM_D : word(3-1 downto 0);
  signal LastRespVal_N, LastRespVal_D : word(DataW-1 downto 0);
begin
  SyncProc : process (Clk, Rst_N)
  begin
    if Rst_N = '0' then
      PS2InitFSM_D <= (others => '0');
      LastRespVal_D <= (others => '0');
    elsif rising_edge(Clk) then
      PS2InitFSM_D <= PS2InitFSM_N;
      LastRespVal_D <= LastRespVal_N;
    end if;
  end process;

  AsyncProc : process (PS2InitFSM_D, PS2DevResp, PS2DevRespVal, RegAccessIn, LastRespVal_D)
    variable CmdVal : bit1;
  begin
    PS2InitFSM_N  <= PS2InitFSM_D;
    PS2HostCmdVal <= '0';
    PS2HostCmd    <= (others => '0');
    Streaming     <= '0';
    LastRespVal_N <= LastRespVal_D;

    if PS2DevRespVal = '1' then
      LastRespVal_N <= PS2DevResp;
    end if;

    case conv_integer(PS2InitFsm_D) is
      when 1 =>
        if PS2DevRespVal = '1' then
          -- Expect Ack
          if PS2DevResp = 16#FA# then
             PS2InitFsm_N <= PS2InitFsm_D + 1;
          else
            -- Try with reset again
             PS2InitFsm_N <= (others => '0');
          end if;
        end if;
      
      when 2 =>
        if PS2DevRespVal = '1' then
          if PS2DevResp = 16#AA# then
             -- Received BAT OK
             PS2InitFsm_N <= PS2InitFsm_D + 1;

          else
            -- Try with reset again
             PS2InitFsm_N <= (others => '0');
          end if;
        end if;

      when 3 =>
        if PS2DevRespVal = '1' then
          if PS2DevResp = 16#00# then
             -- Expect mouse = 0x00
             PS2InitFsm_N <= PS2InitFsm_D + 1;
          else
            -- Try with reset again
             PS2InitFsm_N <= (others => '0');            
          end if;
        end if;

      when 4 =>
        -- Enable data reporting
        PS2HostCmd    <= conv_word(16#F4#, PS2HostCmd'length);
        PS2HostCmdVal <= '1';
        PS2InitFsm_N  <= PS2InitFsm_D + 1;

      when 5 =>
        -- Done state, we are now in stream mode with reporting enabled
        Streaming <= '1';

      when others =>
        -- Send reset
        PS2HostCmd    <= conv_word(16#FF#, PS2HostCmd'length);
        PS2HostCmdVal <= '1';
        PS2InitFsm_N  <= conv_word(1, PS2InitFsm_N'length);        
    end case;

    RegAccessOut <= Z_RegAccessRec;
    if RegAccessIn.Val = "1" then
      if RegAccessIn.Addr = PS2InitState then
        if RegAccessIn.Cmd = REG_READ then
          RegAccessOut.Val                                  <= "1";
          RegAccessOut.Data(PS2InitFsm_D'length-1 downto 0) <= PS2InitFsm_D;
          RegAccessOut.Cmd                                  <= conv_word(REG_READ, RegAccessOut.Cmd'length);
        else
          PS2InitFsm_N <= RegAccessIn.Data(PS2InitFsm_N'length-1 downto 0);
        end if;
      elsif RegAccessIn.Addr = Ps2InitLastResp then
        if RegAccessIn.Cmd = REG_READ then
          RegAccessOut.Val                                   <= "1";
          RegAccessOut.Data(LastRespVal_D'length-1 downto 0) <= LastRespVal_D;
          RegAccessOut.Cmd                                   <= conv_word(REG_READ, RegAccessOut.Cmd'length);
        end if;
      end if;
    end if;
  end process;
  
end architecture rtl;
