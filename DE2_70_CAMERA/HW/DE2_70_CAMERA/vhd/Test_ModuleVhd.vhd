LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

ENTITY bottom_vhdl IS
PORT (a, b : IN std_logic;
      c : OUT std_logic);
END bottom_vhdl;

ARCHITECTURE a OF bottom_vhdl IS
BEGIN
   Process (a, b)
     BEGIN
       c <= a and b;
END process;

END; 
