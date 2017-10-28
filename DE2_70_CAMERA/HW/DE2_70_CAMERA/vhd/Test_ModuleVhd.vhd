library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

library ieee2008;
use float_pkg.all;

ENTITY Test_ModuleVhd IS
PORT (r, g, b : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
      ro, go, bo : OUT STD_LOGIC_VECTOR(9 DOWNTO 0));
END Test_ModuleVhd;

ARCHITECTURE test OF Test_ModuleVhd IS
SIGNAL mean: INTEGER;
SIGNAL rr, gr, br : INTEGER;
BEGIN
   Process (r, g, b)
     BEGIN
     rr <= to_integer(unsigned(r));
     gr <= to_integer(unsigned(g));
     br <= to_integer(unsigned(b));
     if ((rr + gr + br) < 1533) then
       ro <= "0000000000";
       go <= "0000000000";
       bo <= "0000000000";
     else
       ro <= "1111111111";
       go <= "1111111111";
       bo <= "1111111111";
     end if;
END process;

END;