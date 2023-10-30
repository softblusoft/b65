// Copyright 2023 Luca Bertossi
//
// This file is part of B65.
// 
//     B65 is free software: you can redistribute it and/or modify
//     it under the terms of the GNU General Public License as published by
//     the Free Software Foundation, either version 3 of the License, or
//     (at your option) any later version.
// 
//     B65 is distributed in the hope that it will be useful,
//     but WITHOUT ANY WARRANTY; without even the implied warranty of
//     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//     GNU General Public License for more details.
// 
//     You should have received a copy of the GNU General Public License
//     along with B65.  If not, see <http://www.gnu.org/licenses/>.

///////////////////////////////////////////////////////////
// Includes

#include <string.h>

#include "extension.h"
#include "lib.h"
#include "uart.h"
#include "console.h"

///////////////////////////////////////////////////////////
// Globals

// Variable shared with assembler; it's updated in IRQ handler (see isr.s)
unsigned char	g_uart_rx_count;

// Console context
CONSOLE_CONTEXT	g_console_context;

///////////////////////////////////////////////////////////
// Assembler routines

extern void reboot();

///////////////////////////////////////////////////////////
// Functions declaration

void help		(unsigned char *Command);
void cls		(unsigned char *Command);
void echo		(unsigned char *Command);
#if (CONSOLE_MAX_HISTORY > 0)
void history	(unsigned char *Command);
#endif
void display	(unsigned char *Command);
void dump		(unsigned char *Command);
void write		(unsigned char *Command);
void upgrade	(unsigned char *Command);
void escan		(unsigned char *Command);

///////////////////////////////////////////////////////////
// Console commands table

static const CONSOLE_COMMAND g_ConsoleCommand[] =
{
	{	"?",		help,		"show commands help"		},
	{	"cls",		cls,		"clear screen"				},
	{	"echo",		echo,		"echo <string>"				},

// No history command with only the last command
#if (CONSOLE_MAX_HISTORY > 1)
	{	"history",	history,	"history print"				},
#endif

	{	"display",	display,	"display <4 chars> on lcd"	},
	{	"dump",		dump,		"dump <0xstart> <0xlen>"	},
	{	"write",	write,		"set <0xaddress> <0xbyte>"	},

	{	"reboot",	reboot,		"Reboot CPU"				},
	{	"upgrade",	upgrade,	"Start software upgrade"	},

	{	"escan",	escan,		"Escape sequence scan (CTRL+D to stop)"	},
};

///////////////////////////////////////////////////////////
// Functions

///////////////////////////////////////////////////////////
///
/// Show a short help message
///
///	\param	Command		:	User command string
///
///////////////////////////////////////////////////////////
#pragma warn (unused-param, push, off)
void help(unsigned char *Command)
{
	unsigned char Len;
	unsigned char Index;

	for (Index = 0; Index < sizeof(g_ConsoleCommand) / sizeof(CONSOLE_COMMAND); Index++)
	{
		Len = strlen(g_ConsoleCommand[Index].command);
		uartPutstring("  ");
		uartPutstring(g_ConsoleCommand[Index].command);
		Len = 16 - Len;
		while(Len > 0)
		{
			uartPutstring(" ");
			Len--;
		}
		uartPutstring(g_ConsoleCommand[Index].help);
		uartPutstring("\r\n");
	}
}
#pragma warn (unused-param, pop)

///////////////////////////////////////////////////////////
///
/// Send the escape sequence to clear screen
///
///	\param	Command		:	User command string
///
///////////////////////////////////////////////////////////
#pragma warn (unused-param, push, off)
void cls(unsigned char *Command)
{
	uartPutstring("\033[H\033[J");
}
#pragma warn (unused-param, pop)

///////////////////////////////////////////////////////////
///
/// echo a string
///
///	\param	Command		:	User command string
///
///////////////////////////////////////////////////////////
void echo(unsigned char *Command)
{
	uartPutstring(&Command[5]);
}

///////////////////////////////////////////////////////////
///
/// Show the commands history
///
///	\param	Command		:	User command string
///
///////////////////////////////////////////////////////////
#if (CONSOLE_MAX_HISTORY > 1)
#pragma warn (unused-param, push, off)
void history(unsigned char *Command)
{
	unsigned char Index;
	unsigned char Tens	= 0;
	unsigned char Units = 0;

	for (Index = 0; Index < g_console_context.historyCount; Index++)
	{
		uartPutstring("  [");
		uartPutchar('0' + Tens);
		uartPutchar('0' + Units);
		uartPutstring("] ");
		uartPutstring(g_console_context.history[Index]);
		uartPutstring("\r\n");

		Units++;
		if (Units == 10)
		{
			Units = 0;
			Tens++;
		}
	}
}
#pragma warn (unused-param, pop)
#endif

///////////////////////////////////////////////////////////
///
/// Display a string on the four 7-segments led displays
/// of the basys3 board
///
///	\param	Command		:	User command string
///
///////////////////////////////////////////////////////////
void display(unsigned char *Command)
{
	//             0123456789AB
	// Command is "display 1234"
	//                     ||||--> optional characters to display

	unsigned char Len = strlen(Command);

	if (Len >=  9) R_DIGIT3 = Command[ 8]; else R_DIGIT3 = 0; 
	if (Len >= 10) R_DIGIT2 = Command[ 9]; else R_DIGIT2 = 0; 
	if (Len >= 11) R_DIGIT1 = Command[10]; else R_DIGIT1 = 0; 
	if (Len >= 12) R_DIGIT0 = Command[11]; else R_DIGIT0 = 0;
}

///////////////////////////////////////////////////////////
///
/// Dump a memory buffer
///
///	\param	Command		:	User command string
///
/// \note	Command format is
///				dump <start> <size in bytes>
///
///			the output is 8 bytes per line Hex + ascii
///     		00 00 00 00 00 00 00 00 ........
///
///			All parameters must be Hex with '0x' prefix
///
///////////////////////////////////////////////////////////
void dump(unsigned char *Command)
{
	unsigned char		Ascii[12];
	unsigned char		Index	= 0;
	unsigned char		Offset	= 0;
	unsigned short		start;
	unsigned char		length;
	unsigned char		Byte;
	unsigned char	   *data;

	start	= HexToNum(&Command[5], &data);
	length	= HexToNum(data, NULL);
	data	= (unsigned char*) start;

	while (Index < length)
	{
		Byte = data[Index];

		uartPutHexByte(Byte);
		uartPutchar(' ');

		if ((Byte >= 0x20) && (Byte < 0x7F))
			Ascii[Offset] = Byte;
		else
			Ascii[Offset] = '.';

		Index++;
		Offset++;
		if ((Offset == 8) || (Index == length))
		{
			while (Offset < 8)
			{
				uartPutstring("   ");
				Offset++;
			}

			Ascii[Offset++] = '\r';
			Ascii[Offset++] = '\n';
			Ascii[Offset]	= '\0';
			uartPutstring(Ascii);

			Offset = 0;
		}
	}
}

///////////////////////////////////////////////////////////
///
/// Write a single memory location
///
///	\param	Command		:	User command string
///
/// \note	Command format is
///				set <base address> <byte value>
///
///			All parameters must be Hex with '0x' prefix
///
///////////////////////////////////////////////////////////
void write(unsigned char *Command)
{
	unsigned short	base;
	unsigned char	value;
	unsigned char   *data;

	base	= HexToNum(&Command[6], &data);
	value	= HexToNum(data, NULL);
	
	*((unsigned char*) base) = value;
}

///////////////////////////////////////////////////////////
///
/// Upgrade the software (using the UART)
///
///	\param	Command		:	User command string
///
///////////////////////////////////////////////////////////
#pragma warn (unused-param, push, off)
void upgrade(unsigned char *Command)
{
	R_DIGIT3 = 0;
	R_DIGIT2 = 0;
	R_DIGIT1 = 0;
	R_DIGIT0 = 0;
	
	R_MODE |= 0x20;
}
#pragma warn (unused-param, pop)

///////////////////////////////////////////////////////////
///
/// Escape sequence scan until CTR+D (0x04) is received
///
///	\param	Command		:	User command string
///
///////////////////////////////////////////////////////////
#pragma warn (unused-param, push, off)
void escan(unsigned char *Command)
{
	unsigned char Rx	= 0;
	unsigned char Cnt	= 0;
	
	// CTRL+D is 0x04
	while (Rx != 4)
	{
		if (g_uart_rx_count != 0)
		{
			g_uart_rx_count--;
			Rx = R_RX;
			Cnt++;
			
			uartPutHexByte(Rx);
			uartPutchar(' ');

			if (Cnt == 8)
			{
				Cnt = 0;
				uartPutstring("\r\n");
			}
		}
	}	
}
#pragma warn (unused-param, pop)

///////////////////////////////////////////////////////////
// Entry point

///////////////////////////////////////////////////////////
///
/// Entry point
///
///////////////////////////////////////////////////////////
void main(void)
{
	unsigned char	delay;
	unsigned char	regval;
	unsigned char	inval;
	unsigned char	oldval[2]	= { 0, 0 };

	// Enable interrupt (otherwise cpu_irq signal has no effects on software)
	asm("cli");

	R_DIGIT_INTENSITY	= 0x55;
	R_DIGIT3			= 'b';
	R_DIGIT2			= '6';
	R_DIGIT1			= '5';
	R_DIGIT0			= ' ';

	cls(NULL);
	uartPutstring("b65 ready.\r\n");
	ConsoleInit(&g_console_context, g_ConsoleCommand, sizeof(g_ConsoleCommand) / sizeof(CONSOLE_COMMAND) );

	// Enable upgrade to simulate vhdl upgrade process (see b65.vhd download_software.dl_done process)
	// upgrade(0);

	while(1)
	{
		// Delay
		for (delay = 0; delay < 16; ++delay);

		// Console add
		if (g_uart_rx_count != 0)
		{
			g_uart_rx_count--;
			ConsoleAdd(&g_console_context, R_RX);
		}
	
		// Inputs and Leds
		if (R_IN2 != 0)
		{
			// Any pushed button switches on all leds at different intensity
			R_OUT0		= 0x00; // 0000.0000
			R_OUT1		= 0x55; // 0101.0101
			R_OUT2		= 0xAA; // 1010.1010
			R_OUT3		= 0xFF; // 1111.1111
			
			oldval[0] = 0xF0;
			oldval[1] = 0xFF;
		}
		else
		{
			// Mirror slides to leds (7:0)
			inval = R_IN0;
			if (inval != oldval[0])
			{			
				oldval[0] = inval;

				regval = R_OUT0;
				if (inval & 0x01) regval |= 0x03; else regval &= ~0x03;
				if (inval & 0x02) regval |= 0x0C; else regval &= ~0x0C;
				if (inval & 0x04) regval |= 0x30; else regval &= ~0x30;
				if (inval & 0x08) regval |= 0xC0; else regval &= ~0xC0;
				R_OUT0 = regval;
			
				regval = R_OUT1;
				if (inval & 0x10) regval |= 0x03; else regval &= ~0x03;
				if (inval & 0x20) regval |= 0x0C; else regval &= ~0x0C;
				if (inval & 0x40) regval |= 0x30; else regval &= ~0x30;
				if (inval & 0x80) regval |= 0xC0; else regval &= ~0xC0;
				R_OUT1 = regval;
			}
		
			// Mirror slides to leds (15:8)
			inval = R_IN1;
			if (inval != oldval[1])
			{			
				oldval[1] = inval;

				regval = R_OUT2;
				if (inval & 0x01) regval |= 0x03; else regval &= ~0x03;
				if (inval & 0x02) regval |= 0x0C; else regval &= ~0x0C;
				if (inval & 0x04) regval |= 0x30; else regval &= ~0x30;
				if (inval & 0x08) regval |= 0xC0; else regval &= ~0xC0;
				R_OUT2 = regval;

				regval = R_OUT3;
				if (inval & 0x10) regval |= 0x03; else regval &= ~0x03;
				if (inval & 0x20) regval |= 0x0C; else regval &= ~0x0C;
				if (inval & 0x40) regval |= 0x30; else regval &= ~0x30;
				if (inval & 0x80) regval |= 0xC0; else regval &= ~0xC0;
				R_OUT3 = regval;
			}
		}
	}
}
