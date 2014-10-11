library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.Types.all;

package PS2Pack is
  constant PS2Addr       : integer := 16#00000000#;
  constant PS2State      : integer := 16#00000001#;
  constant PS2Sampler    : integer := 16#00000002#;
  constant PS2InitState  : integer := 16#00000003#;
  --
  constant MousePacketState  : integer := 16#00000004#;  
  --
  constant SerFifoLvl    : integer := 16#00000010#;
  constant SerFifoMaxLvl : integer := 16#00000011#;
  --

end package;

package body PS2Pack is

end package body;
