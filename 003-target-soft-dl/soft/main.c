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

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <6502.h>
#include "extension.h"
#include "uart.h"
#include "console.h"

///////////////////////////////////////////////////////////
// Globals

// Variable shared with assembler; it's updated in IRQ handler (see isr.s)
unsigned char	g_uart_rx_count;
CONSOLE_CONTEXT	g_console_context;

///////////////////////////////////////////////////////////
// Functions declaration

void help		(unsigned char *Command, void *Arg);
void cls		(unsigned char *Command, void *Arg);
void history	(unsigned char *Command, void *Arg);
void display	(unsigned char *Command, void *Arg);

///////////////////////////////////////////////////////////
// Commands

static const CONSOLE_COMMAND g_ConsoleCommand[] =
{
	{	"?",		help,	0,		"Show a short commands description"		},
	{	"cls",		cls,	0,		"Clear screen"							},

//	{	"reboot",	0, 0,			"Reboot CPU"							},
//	{	"upgrade",	0, 0,			"Upgrade software"						},

#if (CONSOLE_MAX_HISTORY > 0)
	{	"history",	history, 0,		"Show the commands history"				},
#endif

	{	"display",	display, 0,		"Print 4 chars on 7 segments display"	},

};

///////////////////////////////////////////////////////////
// Functions

// Disable "unused param" warningfor callbacks
#pragma warn (unused-param, push, off)

///////////////////////////////////////////////////////////
///
/// Show a short help message
///
///	\param	Command		:	User command string
///	\param	Arg			:	Optional callback user argument
///
///////////////////////////////////////////////////////////
void help(unsigned char *Command, void *Arg)
{
	unsigned char buffer[32];
	unsigned char fill[16] = "                ";
	unsigned char Len;
	unsigned char Index;
	
	for (Index = 0; Index < sizeof(g_ConsoleCommand) / sizeof(CONSOLE_COMMAND); Index++)
	{
		Len = strlen(g_ConsoleCommand[Index].command);
		fill[12-Len] = '\0';
		sprintf(buffer, "  %s%s%s\r\n", g_ConsoleCommand[Index].command, fill, g_ConsoleCommand[Index].help);
		fill[12-Len] = ' ';
		uartTX(buffer);
	}
}

///////////////////////////////////////////////////////////
///
/// Sen the escape sequence to clear screen
///
///	\param	Command		:	User command string
///	\param	Arg			:	Optional callback user argument
///
///////////////////////////////////////////////////////////
void cls(unsigned char *Command, void *Arg)
{
	uartTX("\033[H\033[J");
}

///////////////////////////////////////////////////////////
///
/// Show the commands history
///
///	\param	Command		:	User command string
///	\param	Arg			:	Optional callback user argument
///
///////////////////////////////////////////////////////////
void history(unsigned char *Command, void *Arg)
{
	unsigned char buffer[32];
	unsigned char Index;
	
	for (Index = 0; Index < g_console_context.historyCount; Index++)
	{
		sprintf(buffer, "[%d] %s\r\n", Index, g_console_context.history[Index]);
		uartTX(buffer);
	}	
}

///////////////////////////////////////////////////////////
///
/// Display a string on the four 7-segments led displays
/// of the basys3 board
///
///	\param	Command		:	User command string
///	\param	Arg			:	Optional callback user argument
///
///////////////////////////////////////////////////////////
void display(unsigned char *Command, void *Arg)
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

	uartTX("b65 ready.\r\n");
	ConsoleInit(&g_console_context, g_ConsoleCommand, sizeof(g_ConsoleCommand) / sizeof(CONSOLE_COMMAND) );

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
