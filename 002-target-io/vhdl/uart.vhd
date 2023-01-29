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
-- uart

----------------------------------------------------------------------------------
--
-- One byte is transmitted as follows (8N1 standard):
-- 
--                   |----- START  -----|-----  BIT 0  -----|      ...      |-----  BIT 7  -----|-----  STOP  -----|-- GUARD --|
-- __________________                    ___________________                 ___________________ _______________________________
--                   |__________________X___________________X      ...      X___________________X
--                                               ^                                                                        ^
--                                               |                                                                        |
--   Sampling Instant ---------------------------+                                                                        |
--                                                                                                                        |
--   Note :                                                                                                               |
--         In this implementation is assumed the line remains idle for some time                                          |
--        (typically half bit duration) after the stop bit : this is defined as a GUARD time -----------------------------+
--
----------------------------------------------------------------------------------

----------------------------------------------------------------------------------
-- Libraries

-- standard libraries
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library b65;

-------------------------------------------------------------------------------
-- Entity

entity uart is
	generic	(
				clock_frequency			:			integer				:= 50000000;		-- clock frequency in hertz
				baud_rate				:			integer				:= 9600;			-- desired baud rate
				start_silence			:			integer				:= 32				-- Number of bytes to discard at start if line is not idle
			);
	port	(
				-- General
				clock					: in		std_logic;								-- Main clock
				reset					: in		std_logic;								-- Reset
				busy					: out		std_logic;								-- High if busy

				-- Serial interface
				uart_rx					: in		std_logic;								-- UART receive pin
				uart_tx					: out		std_logic;								-- UART transmit pin
				
				-- incoming data
				rx_byte					: out		std_logic_vector(7 downto 0);			-- Received data
				rx_valid				: out		std_logic;								-- High if received_data is valid

				-- outgoing data
				tx_byte					: in		std_logic_vector(7 downto 0);			-- Byte to send to UART
				tx_valid				: in		std_logic								-- High for one clock pulse to start transmission
		);
end uart;

-------------------------------------------------------------------------------
-- Architecture

architecture behavioral of uart is

	----------------------------------------------------------------------------
	-- Data types

	-- FSM
	TYPE FSM_CK_UART is (ck_start, ck_idle, ck_wait, ck_low, ck_high);							-- Receive FSM
	TYPE FSM_TX_UART is (tx_idle, tx_send, tx_stop);											-- Transmit FSM
	TYPE FSM_TX_CTRL is (ct_idle, ct_wait_start, ct_wait_end);									-- Transmit Controller FSM

	----------------------------------------------------------------------------
	-- Signals

	-- Resampler
	signal uart_rx_resampled	: std_logic_vector(2  downto 0);								-- Input signal resampled on clock

	-- Clock generator signals (for rx)
	signal clock_rx_state		: FSM_CK_UART;													-- UART clock generator FSM	
	signal clock_rx_counter		: std_logic_vector(15 downto 0);								-- Serial clock generator counter
	signal clock_rx_pulses		: std_logic_vector( 7 downto 0);								-- Number of generated clock pulses before going idle
	signal clock_rx_align		: std_logic_vector(15 downto 0);								-- Serial data alignment
	signal clock_rx_discard		: std_logic_vector( 4 downto 0);								-- Number of byte to discard at start if not aligned
	signal receive_data			: std_logic_vector( 7 downto 0);								-- received data

	-- Clock generator signals (for tx)
	signal clock_tx_state		: FSM_CK_UART;													-- UART clock generator FSM	
	signal clock_tx_serial		: std_logic;													-- Serial clock
	signal clock_tx_counter		: std_logic_vector(15 downto 0);								-- Serial clock generator counter

	-- Serial TX signals
	signal transmit_state		: FSM_TX_UART;													-- UART transmit (serializer) FSM
	signal transmit_data		: std_logic_vector( 7 downto 0);								-- Data to transmit
	signal transmit_sampled		: std_logic_vector( 7 downto 0);								-- Data to transmit
	signal transmit_bit			: std_logic_vector( 3 downto 0);								-- Number of sent bit (excluded start and stop) in the current byte
	signal transmit_start		: std_logic;													-- Transmission start flag
	signal transmit_sending		: std_logic;													-- Transmission sendinf flag

	-- Serial TX Control machine
	signal ctrl_state			: FSM_TX_CTRL;													-- FSM Control state

	-------------------------------------------------------------------------------
	-- Baud rate computation

	function baud_rate_to_full_delay(freq: integer; baud: integer) return std_logic_vector is
	begin
		return conv_std_logic_vector( (freq/baud) - 1, 16);
	end;

	function baud_rate_to_half_delay(freq: integer; baud: integer) return std_logic_vector is
	begin
		return conv_std_logic_vector( (freq/(2*baud)) - 1, 16);
	end;

begin

	-------------------------------------------------------------------------------
	-- RX section

	uart_rx_resample_process : process(clock) begin
		if (clock'event and clock='1') then
			-- If (system is in reset state)
			if (reset = '1') then
				uart_rx_resampled			<= "000";
			else
				uart_rx_resampled(2)		<= uart_rx;
				uart_rx_resampled(1)		<= uart_rx_resampled(2);
				uart_rx_resampled(0)		<= uart_rx_resampled(1);
			end if;
		end if;
	end process;
	
	uart_receiver : process(clock) begin
		if (clock'event and clock='1') then
			-- If (system is in reset state)
			if (reset = '1') then
				clock_rx_counter							<= x"0000";
				clock_rx_pulses								<= x"00";
				clock_rx_state								<= ck_start;
				clock_rx_align								<= x"0000";
				receive_data								<= x"00";
				rx_valid									<= '0';
				clock_rx_discard							<= "00000";
				rx_byte										<= x"00";
			else
				case clock_rx_state is

					when ck_start =>
						rx_valid							<= '0';

						-- line must be high - line idle
						if (uart_rx_resampled(0) = '1') then
							clock_rx_align					<= clock_rx_align + x"0001";
						else
							-- line is low, activity is present before FPGA started, discard some bytes to correctly align
							clock_rx_align					<= x"0000";
							clock_rx_state					<= ck_idle;
							
							-- Number of bytes discarded if after reset line is not idle
							clock_rx_discard				<= conv_std_logic_vector(start_silence, 5);
						end if;

						-- line is high for more than a bit, is considered idle, discard nothing
						if (clock_rx_align > baud_rate_to_full_delay(clock_frequency, baud_rate) ) then
							clock_rx_align					<= x"0000";
							clock_rx_state					<= ck_wait;
							clock_rx_discard				<= "00000";
						end if;					

					-- align with start bit - look for line idle
					when ck_idle =>
						rx_valid							<= '0';

						-- line must be high - line idle
						if (uart_rx_resampled(0) = '1') then
							clock_rx_align					<= clock_rx_align + x"0001";
						else
							clock_rx_align					<= x"0000";
						end if;

						if (clock_rx_align > baud_rate_to_half_delay(clock_frequency, baud_rate)) then
							clock_rx_state					<= ck_wait;
						end if;

					-- wait for start condition, in order to be aligned with data
					when ck_wait =>
						clock_rx_counter					<= x"0000";
						clock_rx_pulses						<= x"00";
						rx_valid							<= '0';

						-- wait for start condition
						if (uart_rx_resampled(0) = '0') then
							clock_rx_counter				<= clock_rx_counter + x"0001";
							
							-- Go to high state half bit length
							if (clock_rx_counter = baud_rate_to_half_delay(clock_frequency, baud_rate)) then
								clock_rx_state				<= ck_high;
							end if;
						end if;

					-- clock high - only one clock pulse
					when ck_high =>
						clock_rx_state						<= ck_low;
						clock_rx_counter					<= x"0000";							-- reset clock counter
						clock_rx_pulses						<= clock_rx_pulses + x"01";
						rx_valid							<= '0';

						-- After 10 clock pulses return waiting for the start condition (1 start + 8 bit + 1 stop)
						if (clock_rx_pulses = x"09") then
							clock_rx_align					<= x"0000";
							clock_rx_state					<= ck_idle;
							
							-- At stop line must be high
							if (uart_rx_resampled(0) = '1') then
								if (clock_rx_discard = "00000") then
									rx_valid				<= '1';
									rx_byte					<= receive_data;
								else
									clock_rx_discard		<= clock_rx_discard - "00001";
								end if;
							end if;
						else
							-- Shift serial data and generate final byte
							receive_data					<= uart_rx_resampled(0) & receive_data(7 downto 1);
						end if;

					-- clock low
					when ck_low =>
						clock_rx_state						<= ck_low;
						clock_rx_counter					<= clock_rx_counter + x"0001";		-- reset clock counter
						rx_valid							<= '0';

						-- go to high state
						if (clock_rx_counter = baud_rate_to_full_delay(clock_frequency, baud_rate)) then
							clock_rx_state					<= ck_high;
						end if;

					-- Alignment state
					when others =>
						clock_rx_state						<= ck_idle;
						clock_rx_align						<= x"0000";

				end case;
			end if; -- reset
		end if; -- clock
	end process;

	-------------------------------------------------------------------------------
	-- TX section

	-----------------------------------
	-- Process : timing generator
	uart_tx_timing : process(clock) begin
		if (clock'event and clock='1') then
			-- If (system is in reset state)
			if (reset = '1') then
				clock_tx_serial								<= '0';
				clock_tx_counter							<= x"0000";
				clock_tx_state								<= ck_low;
			else
				case clock_tx_state is

					-- clock high - only one clock pulse
					when ck_high =>
						clock_tx_state						<= ck_low;
						clock_tx_serial						<= '1';								-- set clock high - trigger data sample/generation
						clock_tx_counter					<= x"0000";							-- reset clock counter

					-- clock low
					when ck_low =>
						clock_tx_state						<= ck_low;
						clock_tx_serial						<= '0';								-- set clock low
						clock_tx_counter					<= clock_tx_counter + x"0001";		-- reset clock counter

						-- go to high state
						if (clock_tx_counter = baud_rate_to_full_delay(clock_frequency, baud_rate)) then
							clock_tx_state					<= ck_high;
						end if;

					-- Alignment state
					when others =>
						clock_tx_state						<= ck_low;

				end case;
			end if; -- reset
		end if; -- clock
	end process;

	-----------------------------------
	-- Process : serializer
	uart_serializer : process(clock) begin
		if (clock'event and clock='1') then
			-- If (system is in reset state)
			if (reset = '1') then
				transmit_state								<= tx_idle;							-- reset FSM
				uart_tx										<= '1';								-- tx is high = inactive
				transmit_bit								<= x"0";
				transmit_sending							<= '0';
				transmit_data								<= x"00";
			else
				if (clock_tx_serial = '1') then
					case transmit_state is

						-- Idle
						when tx_idle =>
							transmit_state					<= tx_idle;
							uart_tx							<= '1';								-- inactive
							transmit_bit					<= x"0";
							transmit_sending				<= '0';

							if (transmit_start = '0') then
								transmit_data				<= transmit_sampled;
								transmit_state				<= tx_send;
								transmit_sending			<= '1';
								uart_tx						<= '0';								-- start
							end if;
							
						when tx_send =>
							transmit_state					<= tx_send;
							transmit_sending				<= '1';
							transmit_data					<= '0' & transmit_data(7 downto 1);
							uart_tx							<= transmit_data(0);
							transmit_bit					<= transmit_bit + x"1";
							
							if (transmit_bit = x"7") then
								transmit_state				<= tx_stop;
								transmit_bit				<= x"0";
							end if;

						when tx_stop =>
							transmit_state					<= tx_idle;
							transmit_sending				<= '1';
							uart_tx							<= '1';								-- stop

						-- Alignment state
						when others =>
							transmit_state					<= tx_idle;

					end case;
				end if;
			end if; -- reset
		end if; -- clock
	end process;

	-----------------------------------
	-- Process : transmit control
	tx_uart_control : process(clock) begin
		if (clock'event and clock='1') then
			-- If (system is in reset state)
			if (reset = '1') then
				busy										<= '0';
				transmit_start								<= '1';
				transmit_sampled							<= x"00";
				ctrl_state									<= ct_idle;
			else
				case ctrl_state is

					-- Idle
					when ct_idle =>
						ctrl_state							<= ct_idle;
						busy								<= '0';
						transmit_start						<= '1';

						-- If data valid, start sending
						if (tx_valid = '1') then
							ctrl_state						<= ct_wait_start;
							transmit_start					<= '0';
							transmit_sampled				<= tx_byte;
							busy							<= '1';
						end if;

					-- Wait for tx machine (low speed clock) starts
					when ct_wait_start =>
						ctrl_state							<= ct_wait_start;
						busy								<= '1';
						transmit_start						<= '0';

						if (transmit_sending = '1') then
							ctrl_state						<= ct_wait_end;
						end if;

					-- Wait for tx machine (low speed clock) ends
					when ct_wait_end =>
						ctrl_state							<= ct_wait_end;
						busy								<= '1';
						transmit_start						<= '1';

						if (transmit_sending = '0') then
							ctrl_state						<= ct_idle;
						end if;

					-- Alignment state
					when others =>
						ctrl_state							<= ct_idle;

				end case;
			end if; -- reset
		end if; -- clock
	end process;

end behavioral;

-------------------------------------------------------------------------------
-- EOF
