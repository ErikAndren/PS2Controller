library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.Types.all;


package SerialPack is
  constant NewLine   : word(8-1 downto 0) := x"0A";
  constant WriteCmd  : word(8-1 downto 0) := x"57";
  constant ReadCmd   : word(8-1 downto 0) := x"52";
  constant SpaceChar : word(8-1 downto 0) := x"20";
  --
  constant W         : word(8-1 downto 0) := x"57";
  constant Space     : word(8-1 downto 0) := x"20";

  constant REG_READ  : natural  := 0;
  constant REG_WRITE : natural  := 1;
  constant RegCmdW   : natural  := REG_WRITE;
  constant AddrW     : positive := 32;
  constant DataW     : positive := 32;
  
  -- 1 + 2 + 32 + 32 
  type RegAccessRec is record
    Val  : word1;
    Cmd  : word(RegCmdW-1 downto 0);
    Addr : word(AddrW-1 downto 0);
    Data : word(DataW-1 downto 0);
  end record;

  function RegAccessRecToWord(Rec : RegAccessRec) return word;
  function WordToRegAccessRec(W   : word) return RegAccessRec;

  constant Z_RegAccessRec : RegAccessRec :=
    (Val  => "0",
     Data => (others => '0'),
     Cmd  => (others => '0'),
     Addr => (others => '0')
     );

  -- 66
  constant RegAccessRecW : positive := word1'length + RegCmdW + AddrW + DataW;
  
end package;

package body SerialPack is
  function RegAccessRecToWord(Rec : RegAccessRec) return word is
    variable res : word(RegAccessRecW-1 downto 0);
  begin
    return Rec.Addr &
           Rec.Cmd &
           Rec.Data &
           Rec.Val; 
  end function;
      
  function WordToRegAccessRec(W : word) return RegAccessRec is
    variable R    : RegAccessRec;
    variable i, j : natural;
  begin
    i := W'length;
    j := i - R.Addr'length; R.Addr := W(i-1 downto j); i := j;
    j := i - R.Cmd'length; R.Cmd := W(i-1 downto j); i := j;
    j := i - R.Data'length; R.Data := W(i-1 downto j); i := j;
    j := i - R.Val'length; R.Val := W(i-1 downto j); i := j;
    assert i = 0 report "Word to record mismatch" severity failure;
    return R;
  end function;  
end package body;
