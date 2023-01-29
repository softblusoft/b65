-- Copyright 2023 Luca Bertossi
--
-- This file is part of B65.
-- 
--     B65 is free software: you can redistribute it and/or modify
--     it under the terms of the GNU General Public License as published by
--     the Free Software Foundation, either version 3 of the License, or
--     (at your option) any later version.
-- 
--     B65 is distributed in the hope that it will be useful,
--     but WITHOUT ANY WARRANTY; without even the implied warranty of
--     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--     GNU General Public License for more details.
-- 
--     You should have received a copy of the GNU General Public License
--     along with B65.  If not, see <http://www.gnu.org/licenses/>.

----------------------------------------------------------------------------------
-- Extension block

-- Registers map (default all to zero)
--
--	Reg[0] : [RW] Mode
--			bit[7] = unused
--			bit[6] = unused
--			bit[5] = unused
--			bit[4] = UART rx interrupt      (0=disable         , 1=enable)
--			bit[3] = input change interrupt (0=disable         , 1=enable)
--			bit[2] = output invert          (0=don't invert    , 1=invert)
--			bit[1] = digits invert          (0=don't invert    , 1=invert)
--			bit[0] = digits direct drive    (0=use CHARMAP     , 1=direct drive '.gfedcba')
--	
--	Reg[1] : [RW] outputs(n= 0)  3,  2,  1,  0
--	Reg[2] : [RW] outputs(n= 4)  7,  6,  5,  4
--	Reg[3] : [RW] outputs(n= 8) 11, 10,  9,  8
--	Reg[4] : [RW] outputs(n=12) 15, 14, 13, 12
--			bit[7:6] = output n+3 mode (00 = off, 01 = 33% PWM , 10 = 66% PWM, 11 = full on)
--			bit[5:4] = output n+2 mode
--			bit[3:2] = output n+1 mode
--			bit[1:0] = output n+0 mode
--	
--	Reg[5] : [RW] led digits intensity
--			bit[7:6] = digit  3 mode (00 = off, 01 = 33% PWM , 10 = 66% PWM, 11 = full on)
--			bit[5:4] = digit  2 mode
--			bit[3:2] = digit  1 mode
--			bit[1:0] = digit  0 mode
--	
--	Reg[6] : [RO] input [ 7: 0] value
--	Reg[7] : [RO] input [15: 8] value
--	Reg[8] : [RO] input [23:16] value
--	
--	Reg[9] : [RW] digit 0 value
--	Reg[A] : [RW] digit 1 value
--	Reg[B] : [RW] digit 2 value
--	Reg[C] : [RW] digit 3 value
--	
--	Reg[D] : [RO] number of characters ready from UART
--	Reg[E] : [RO] UART Rx character
--	Reg[F] : [WO] UART Tx character
--

-------------------------------------------------------------------------------
-- Libraries

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

library b65;
use b65.PACK.all;

-------------------------------------------------------------------------------
-- Entity

entity ext is
	port	(
				-- General
				clock					: in		std_logic;								-- Clock
				reset					: in		std_logic;								-- reset
				enable					: in		std_logic;								-- block enable
				interrupt				: out		std_logic;								-- interrupt (active low)

				-- Write interface
				write_address			: in		std_logic_vector( 3	downto 0);			-- write Address
				write_enable			: in		std_logic;								-- Write enable
				write_data				: in		std_logic_vector( 7	downto 0);			-- Data IN

				-- Read interface
				read_address			: in		std_logic_vector( 3	downto 0);			-- read Address
				read_data				: out		std_logic_vector( 7	downto 0);			-- Data OUT
				
				-- I/O
				outputs					: out		std_logic_vector(15	downto 0);			-- Output wires
				inputs					: in		std_logic_vector(23	downto 0);			-- Input  wires
				digit					: out		LED7X4;									-- 4x 7-segments digits
				uart_rx					: in		std_logic;								-- UART receive
				uart_tx					: out		std_logic								-- UART transmit
			);
end ext;

-------------------------------------------------------------------------------
-- Architecture

architecture behavioral of ext is

	----------------------------------------------------------------------------
	-- Constants

	constant UART_FIFO_DEPTH : integer := 32;

	----------------------------------------------------------------------------
	-- Data types

	-- Memory data
	type REGISTERS	is array(0 to  15) of std_logic_vector(7 downto 0);

	-- Led display char map (Ascii 0:127)
	type CHARMAP	is array(0 to 127) of std_logic_vector(7 downto 0);

	-- UART fifo
	type UART_FIFO	is array(0 to UART_FIFO_DEPTH) of std_logic_vector(7 downto 0);

	-- Static display value
	signal digit_val			: LED7X4;

	-- Read / Write
	signal read_keep			: std_logic;	-- Keep the samme value to read_data while enable is high 
	signal write_once			: std_logic;	-- Write once a register             while enable is high 

	-- PWM counter
	signal pwm_counter			: std_logic_vector(7 downto 0);

	-- Interrupt
	signal int_delay			: std_logic_vector(7 downto 0);
	signal int_trigger_input	: std_logic;
	signal int_trigger_uart		: std_logic;
	
	-- UART serializer component
	signal uart_busy			: std_logic;
	signal uart_rx_byte			: std_logic_vector(7 downto 0);
	signal uart_rx_valid		: std_logic;
	signal uart_tx_byte			: std_logic_vector(7 downto 0);
	signal uart_tx_valid		: std_logic;
	
	-- UART rx fifo
	signal uart_rx_write		: integer range 0 to UART_FIFO_DEPTH;
	signal uart_rx_read			: integer range 0 to UART_FIFO_DEPTH;
	signal uart_rx_count		: std_logic_vector(7 downto 0);
	signal uart_rx_fifo			: UART_FIFO;

	-- UART tx fifo
	signal uart_tx_send			: std_logic;
	signal uart_tx_write		: integer range 0 to UART_FIFO_DEPTH;
	signal uart_tx_read			: integer range 0 to UART_FIFO_DEPTH;
	signal uart_tx_count		: std_logic_vector(7 downto 0);
	signal uart_tx_fifo			: UART_FIFO;

	----------------------------------------------------------------------------
	-- Constants

	-- Ascii (0:127) charmap remapped to LCD 7 segments display
	-- bit 7 is always zero (it's the LCD dot, direcly connected to the register bit 7)
	-- Zero means led off
	-- Some (or most) rapresented chars must be viewed with a bit of imagination
	--
	--   --              a
	--  |  |           f   b
	--   --     --->     g     ---> std_logic_vector(7 downto 0) = .fedcba
	--  |  |           e   c 
	--   --  .           d   .
	constant LED_CHAR		: CHARMAP := 
	(
		-- [0:31] ascii chars are not used
		x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00",
		x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00",
		
		-- [32:63]  = SPACE !"#$%&'()*+,-./0123456789:;<=>?
		--             |    ||||||   ||              ||| ||
		--            off   ||||||   ||              ||| ||
		--                  cannot be rapresented on 7 segments
		--' '    !      "      #      $      %      &     '      (       )      *      +      ,      -      .      /
		x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"02", x"39", x"0F", x"00", x"00", x"80", x"40", x"80", x"52",
		--0      1      2      3      4      5      6      7      8      9      :      ;      <      =      >      ?
		x"3F", x"06", x"5B", x"4F", x"66", x"6D", x"7D", x"07", x"7F", x"6F", x"00", x"00", x"00", x"48", x"00", x"00",
		
		-- [64:95]  = @ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_
		--            |          | |         |
		--            cannot be rapresented on 7 segments
		--
		--@      A      B      C      D      E      F      G      H      I      J      K      L      M      N      O
		x"00", x"77", x"7C", x"39", x"5E", x"79", x"71", x"7D", x"76", x"06", x"1E", x"00", x"38", x"00", x"54", x"3F",
		--P      Q      R      S      T      U      V      W      X      Y      Z      [      \      ]      ^      _
		x"73", x"67", x"50", x"6D", x"78", x"3E", x"3E", x"00", x"76", x"66", x"5B", x"39", x"64", x"0F", x"23", x"08",

		-- [96:127] = `abcdefghijklmnopqrstuvwxyz{|}~ DELETE
		--            |          | |         |   | || |
		--           cannot be rapresented on 7 segments		
		--`      a      b      c      d      e      f      g      h      i      j      k      l      m      n      o
		x"20", x"5F", x"7C", x"58", x"5E", x"79", x"71", x"6F", x"74", x"04", x"0E", x"00", x"38", x"00", x"54", x"5C",
		--p      q      r      s      t      u      v      w      x      y      z      {      |      }      ~      DEL
		x"73", x"67", x"50", x"6D", x"78", x"1C", x"1C", x"00", x"76", x"66", x"5B", x"00", x"06", x"00", x"00", x"00"
	);

	----------------------------------------------------------------------------
	-- Signals

	-- Registers memory
	signal reg : REGISTERS;

begin

	----------------------------------------------------------------------------
	-- Components map
	
	inst_uart : uart
	port map	(
					-- General
					clock						=> clock,
					reset						=> reset,
					busy						=> uart_busy,

					-- Serial interface
					uart_rx						=> uart_rx,
					uart_tx						=> uart_tx,
		
					-- incoming data
					rx_byte						=> uart_rx_byte,
					rx_valid					=> uart_rx_valid,

					-- outgoing data
					tx_byte						=> uart_tx_byte,
					tx_valid					=> uart_tx_valid
		);

	----------------------------------------------------------------------------
	-- Processes

	-- Register read and UART RX
	ext_read  : process(clock) begin
		if (clock'event and clock='1') then

			-- UART RX fifo
			if (reset = '1') then
				uart_rx_write					<= 0;
				uart_rx_read					<= 0;
				uart_rx_count					<= (others => '0');
				uart_rx_fifo					<= (others => (others => '0'));
				int_trigger_uart				<= '0';
			else
				int_trigger_uart				<= '0';

				-- Insert serializer received data into the rx fifo
				if (uart_rx_valid = '1') then
					uart_rx_count				<= uart_rx_count + 1;
					uart_rx_fifo(uart_rx_write)	<= uart_rx_byte;
					if (uart_rx_write = UART_FIFO_DEPTH) then
						uart_rx_write			<= 0;
					else
						uart_rx_write			<= uart_rx_write + 1;
					end if;
					int_trigger_uart			<= '1';
				end if;
			end if;

			-- Standard registers read (Reg[F] is write only)
			if (reset = '1') then
				read_data						<= (others => '0');
				read_keep						<= '0';
			elsif (read_keep = '1') then
			
				-- Prevent to modify read_data output while enable is high
				if (enable = '0') then
					read_keep					<= '0';
				end if;

			elsif (enable = '1') and (read_keep = '0') and (conv_integer(read_address) <= 14) and (write_enable = '0') then
				
				read_keep						<= '1';

				if (read_address = x"0D") then
					-- number of characters ready from UART
					read_data					<= uart_rx_count;
					
					-- synthesis translate_off
					Log("INFO : ext Read UART count[" & integer'image(conv_integer(uart_rx_count)) & "]");
					-- synthesis translate_on

				elsif (read_address = x"0E") then
					-- UART RX
					if (uart_rx_count > 0) then
						uart_rx_count				<= uart_rx_count - 1;
						read_data					<= uart_rx_fifo(uart_rx_read);	
						if (uart_rx_read = UART_FIFO_DEPTH) then
							uart_rx_read			<= 0;
						else
							uart_rx_read			<= uart_rx_read + 1;
						end if;					

						-- synthesis translate_off
						Log("INFO : ext Read UART RX '" & character'val(conv_integer(uart_rx_fifo(uart_rx_read))) & "' [" & integer'image(conv_integer(uart_rx_count)) & "] byte/s)");
						-- synthesis translate_on
					else
						read_data					<= (others => '0');

						-- synthesis translate_off
						Log("INFO : ext Read UART RX but no data available");
						-- synthesis translate_on
					
					end if;
				else
					read_data					<= reg(conv_integer(read_address));

					-- synthesis translate_off
					Log("INFO : ext Read  REG[" & integer'image(conv_integer(read_address)) & "]<-[" & integer'image(conv_integer(reg(conv_integer(read_address)))) & "]");
					-- synthesis translate_on
				end if;
			end if; -- reset
			
			-- Prevent to modify the fifo item count if there is a write and read in the same cycle
			if (reset = '0') and (enable = '1') and (uart_rx_valid = '1') and (read_address = x"0E") then
				uart_rx_count					<= uart_rx_count;
			end if;

		end if; -- clock event
	end process;

	-- Register write
	ext_write  : process(clock)
	
		-- Set a digit (not pwm)
		procedure PROC_SET_DIGIT(constant id : in integer) is begin
			if (reg(0)(1) = '0') then
				-- Don't invert
				if (reg(0)(0) = '0') then
					digit_val(id)(7)			<= LED_CHAR(conv_integer(write_data))(7);							-- map bit 7 to LCD dot
					digit_val(id)(6 downto 0)	<= LED_CHAR(conv_integer(write_data))(6 downto 0);					-- map register value to LCD
				else
					digit_val(id)(7)			<= write_data(7);													-- drive dot
					digit_val(id)(6 downto 0)	<= write_data(6 downto 0);											-- direct drive
				end if;
			else
				-- Invert				
				if (reg(0)(0) = '0') then
					digit_val(id)(7)			<= not LED_CHAR(conv_integer(write_data))(7);						-- map bit 7 to LCD dot
					digit_val(id)(6 downto 0)	<= not LED_CHAR(conv_integer(write_data))(6 downto 0);				-- map register value to LCD
				else
					digit_val(id)(7)			<= not write_data(7);												-- drive dot
					digit_val(id)(6 downto 0)	<= not write_data(6 downto 0);										-- direct drive
				end if;
			end if;
		end PROC_SET_DIGIT;

		-- Detect a change in input and trigger interrupt
		procedure PROC_INPUT(constant id : in integer; constant up : in integer; constant dn : in integer) is begin
			if (reg(id) /= inputs(up downto dn)) then
				reg(0)(3)						<= '1';
				reg(id)							<= inputs(up downto dn);
				int_trigger_input				<= '1';
			end if;
		end PROC_INPUT;

	begin
		if (clock'event and clock='1') then
			-- If reset
			if (reset = '1') then
				-- Reset
				for address in 0 to 15 loop
					reg(address)	<= (others => '0');
				end loop;
				
				digit_val			<= (others => (others => '0'));
				int_trigger_input	<= '0';
				uart_tx_send		<= '0';
				write_once			<= '0';
			else
				int_trigger_input	<= '0';
				uart_tx_send		<= '0';

				-- Inputs to registers (regardless of enable)
				PROC_INPUT(6,  7, 0);							-- Reg[6] : [RO] input [ 7: 0] value				
				PROC_INPUT(7, 15, 8);							-- Reg[7] : [RO] input [15: 8] value
				PROC_INPUT(8, 23,16);							-- Reg[8] : [RO] input [23:16] value

				-- Registers action
				if (write_enable = '1') and (enable = '1') and (write_once = '0') then
					case (write_address) is
				--		when x"0"	=> null;					-- Reg[0] : [RW] Mode
				--		when x"1"	=> null;					-- Reg[1] : [RW] outputs  3,  2,  1,  0				
				--		when x"2"	=> null;					-- Reg[2] : [RW] outputs  7,  6,  5,  4
				--		when x"3"	=> null;					-- Reg[3] : [RW] outputs 11, 10,  9,  8
				--		when x"4"	=> null;					-- Reg[4] : [RW] outputs 15, 14, 13, 12
				--		when x"5"	=> null;					-- Reg[5] : [RW] led digits intensity
				--		when x"6"	=> null;					-- Reg[6] : [RO] input [ 7: 0] value				
				--		when x"7"	=> null;					-- Reg[7] : [RO] input [15: 8] value
				--		when x"8"	=> null;					-- Reg[8] : [RO] input [23:16] value
						when x"9"	=> PROC_SET_DIGIT(0);		-- Reg[9] : [RW] digit 0 value
						when x"A"	=> PROC_SET_DIGIT(1);		-- Reg[A] : [RW] digit 1 value
						when x"B"	=> PROC_SET_DIGIT(2);		-- Reg[B] : [RW] digit 2 value
						when x"C"	=> PROC_SET_DIGIT(3);		-- Reg[C] : [RW] digit 3 value
				--		when x"D"	=> null;					-- Reg[D] : [RO] number of characters ready from UART
				--		when x"E"	=> null;					-- Reg[E] : [RO] UART Rx character
						when x"F"	=> uart_tx_send <= '1';		-- Reg[F] : [WO] UART Tx character
						when others	=> null;
					end case;
				end if;

				-- Register Write (Reg[E,D,8,7,6] are read only)
				if (write_enable = '1') and (enable = '1') and (write_once = '0') and
					( (conv_integer(write_address) <= 5) or 
					 ((conv_integer(write_address) >= 9) and (conv_integer(write_address) <= 12)) or
					 ((conv_integer(write_address) = 15))) then

					-- synthesis translate_off
					if (conv_integer(write_address) = 15) then
						Log("INFO : ext UART TX '" & character'val(conv_integer(write_data)) & "'");
					else
						Log("INFO : ext Write REG[" & integer'image(conv_integer(write_address)) & "]->[" & integer'image(conv_integer(write_data)) & "]");
					end if;
					-- synthesis translate_on

					reg(conv_integer(write_address))	<= write_data;
					write_once							<= '1';
				end if;
				
				if (enable = '0') then
					write_once <= '0';
				end if;
				
				-- Set register(0) bit(4) : UART rx interrupt
				if (int_trigger_uart = '1') then
					reg(0)(4) <= '1';
				end if;
				
			end if; -- reset
		end if; -- clock event
	end process;

	-- Interrupt generator
	-- interrupt must be active some clock pulses
	int_generator : process(clock) begin
		if (clock'event and clock='1') then
			-- If (system is in reset state)
			if (reset = '1') then
				int_delay				<= (others => '0');
				interrupt				<= '1';
			else
				interrupt				<= '1';

				if (int_trigger_input = '1') or (int_trigger_uart = '1') then
					interrupt			<= '0';
					int_delay			<= x"40";

					-- synthesis translate_off
					if (int_trigger_input = '1') then
						Log("INFO : ext IRQ (input)");
					end if;
					if (int_trigger_uart = '1') then
						Log("INFO : ext IRQ (uart receive '" & character'val(conv_integer(uart_rx_byte)) & "' [" & integer'image(conv_integer(uart_rx_count)) & "]bytes)");
					end if;
					-- synthesis translate_on				
				end if;

				if (int_delay /= x"00") then
					int_delay			<= int_delay - x"01";
					interrupt			<= '0';
				end if;
			end if; -- reset
		end if; -- clock event
	end process;

	-- pwm counter
	pwm_generator : process(clock) begin
		if (clock'event and clock='1') then
			-- If (system is in reset state)
			if (reset = '1') then
				pwm_counter				<= x"00";
			else
				-- Increment PWM counter
				pwm_counter				<= pwm_counter + x"01";
			end if; -- reset
		end if; -- clock event
	end process;

	-- generate the digit pwm output
	set_pwm_digit : process(clock)
	
		-- Set a digit
		procedure PROC_SET_OUT(constant id : in integer; signal val : in std_logic_vector(1 downto 0)) is begin

			digit(id)			<= (others => '0');

			if (val = "00") then
				digit(id)		<= (others => '0');
			elsif (val = "01") then
				if (pwm_counter > x"AA") then
					digit(id)	<= digit_val(id);
				end if;
			elsif (val = "10") then
				if (pwm_counter > x"55") then
					digit(id)	<= digit_val(id);
				end if;
			else
				digit(id)		<= digit_val(id);
			end if;		
		end procedure;
	begin
		if (clock'event and clock='1') then
			-- If (system is in reset state)
			if (reset = '1') then
				digit			<= (others => (others => '0'));
			else
				PROC_SET_OUT(0, reg(5)(1 downto 0));
				PROC_SET_OUT(1, reg(5)(3 downto 2));
				PROC_SET_OUT(2, reg(5)(5 downto 4));
				PROC_SET_OUT(3, reg(5)(7 downto 6));
			end if; -- reset
		end if; -- clock event
	end process;

	-- generate all the outputs
	set_outputs : process(clock)
		
		-- Set the output bit 'oid'
		procedure PROC_SET_OUT(constant oid : in integer; signal val : in std_logic_vector(1 downto 0)) is begin
			outputs(oid)			<= reg(0)(2);
			if (val = "00") then
				outputs(oid)		<= reg(0)(2);
			elsif (val = "01") then
				if (pwm_counter > x"AA") then
					outputs(oid)	<= not reg(0)(2);
				end if;
			elsif (val = "10") then
				if (pwm_counter > x"55") then
					outputs(oid)	<= not reg(0)(2);
				end if;
			else
				outputs(oid)		<= not reg(0)(2);
			end if;
		end PROC_SET_OUT;

	begin
		if (clock'event and clock='1') then
			-- If (system is in reset state)
			if (reset = '1') then
				outputs <= (others => '0');
			else
				PROC_SET_OUT( 0, reg(1)(1 downto 0));
				PROC_SET_OUT( 1, reg(1)(3 downto 2));
				PROC_SET_OUT( 2, reg(1)(5 downto 4));
				PROC_SET_OUT( 3, reg(1)(7 downto 6));
				
				PROC_SET_OUT( 4, reg(2)(1 downto 0));
				PROC_SET_OUT( 5, reg(2)(3 downto 2));
				PROC_SET_OUT( 6, reg(2)(5 downto 4));
				PROC_SET_OUT( 7, reg(2)(7 downto 6));

				PROC_SET_OUT( 8, reg(3)(1 downto 0));
				PROC_SET_OUT( 9, reg(3)(3 downto 2));
				PROC_SET_OUT(10, reg(3)(5 downto 4));
				PROC_SET_OUT(11, reg(3)(7 downto 6));

				PROC_SET_OUT(12, reg(4)(1 downto 0));
				PROC_SET_OUT(13, reg(4)(3 downto 2));
				PROC_SET_OUT(14, reg(4)(5 downto 4));
				PROC_SET_OUT(15, reg(4)(7 downto 6));
			end if; -- reset
		end if; -- clock event
	end process;
	
	-- UART tx fifo
	proc_uart_tx_fifo : process(clock) begin
		if (clock'event and clock='1') then
			-- If (system is in reset state)
			if (reset = '1') then
				uart_tx_write					<= 0;
				uart_tx_read					<= 0;
				uart_tx_count					<= (others => '0');
				uart_tx_fifo					<= (others => (others => '0'));

				uart_tx_byte					<= (others => '0');
				uart_tx_valid					<= '0';
			else
				uart_tx_valid					<= '0';

				-- Insert reg(15) into the tx fifo
				if (uart_tx_send = '1') then
					uart_tx_count				<= uart_tx_count + 1;
					uart_tx_fifo(uart_tx_write)	<= reg(15);
					if (uart_tx_write = UART_FIFO_DEPTH) then
						uart_tx_write			<= 0;
					else
						uart_tx_write			<= uart_tx_write + 1;
					end if;					
				end if;
				
				-- Send one byte to the serializer
				if (uart_tx_count /= x"00") and (uart_busy = '0') and (uart_tx_valid = '0') then
					uart_tx_count				<= uart_tx_count - 1;
					uart_tx_byte				<= uart_tx_fifo(uart_tx_read);
					uart_tx_valid				<= '1';				
					if (uart_tx_read = UART_FIFO_DEPTH) then
						uart_tx_read			<= 0;
					else
						uart_tx_read			<= uart_tx_read + 1;
					end if;					
				end if;

				-- Prevent to modify the fifo item count if there is a write and read in the same cycle
				if (uart_tx_send = '1') and (uart_tx_count /= x"00") and (uart_busy = '0') and (uart_tx_valid = '0') then
					uart_tx_count				<= uart_tx_count;
				end if;
			end if; -- reset
		end if; -- clock event
	end process;

end behavioral;

-------------------------------------------------------------------------------
-- EOF
