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

#include <6502.h>

// Extension registers
#define REGEXT_BASE				0xDC00
#define R_MODE					(*((unsigned char*) REGEXT_BASE + 0x00))
#define R_OUT0					(*((unsigned char*) REGEXT_BASE + 0x01))
#define R_OUT1					(*((unsigned char*) REGEXT_BASE + 0x02))
#define R_OUT2					(*((unsigned char*) REGEXT_BASE + 0x03))
#define R_OUT3					(*((unsigned char*) REGEXT_BASE + 0x04))
#define R_DIGIT_INTENSITY		(*((unsigned char*) REGEXT_BASE + 0x05))
#define R_IN0					(*((unsigned char*) REGEXT_BASE + 0x06))
#define R_IN1					(*((unsigned char*) REGEXT_BASE + 0x07))
#define R_IN2					(*((unsigned char*) REGEXT_BASE + 0x08))
#define R_DIGIT0				(*((unsigned char*) REGEXT_BASE + 0x09))
#define R_DIGIT1				(*((unsigned char*) REGEXT_BASE + 0x0A))
#define R_DIGIT2				(*((unsigned char*) REGEXT_BASE + 0x0B))
#define R_DIGIT3				(*((unsigned char*) REGEXT_BASE + 0x0C))
#define R_RX_COUNT				(*((unsigned char*) REGEXT_BASE + 0x0D))
#define R_RX					(*((unsigned char*) REGEXT_BASE + 0x0E))
#define R_TX					(*((unsigned char*) REGEXT_BASE + 0x0F))

// Variable shared with assembler (see isr.s)
unsigned char uart_rx_count;

// Uart Rx Buffer
unsigned char uart_rx_index;
unsigned char uart_rx_buffer[32];


// String UART transmit
void __fastcall__ uartTX(const char *buf)
{
	while(*buf)
	{
		R_TX = *buf;
		++buf;
	}
}

// Entry point
void main(void)
{
	unsigned char delay;
	unsigned char regval;
	unsigned char inval;
	unsigned char oldval[2]	= { 0, 0 };
	unsigned char rxval;

	// Enable interrupt (otherwise cpu_irq signal has no effects on software)
	asm("cli");

	R_DIGIT_INTENSITY	= 0x55;
	R_DIGIT3			= 'b';
	R_DIGIT2			= '6';
	R_DIGIT1			= '5';
	R_DIGIT0			= ' ';

	uartTX("b65 ready.\r\n");

	uart_rx_index  = 0;

	while(1)
	{
		// Delay
		for (delay = 0; delay < 16; ++delay);

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
	
		// uart_rx_count is updated in IRQ handler (see isr.s)
		if (uart_rx_count != 0)
		{
			uart_rx_count--;
			rxval = R_RX;
			
			// Echo uart
			R_TX = rxval;
			
			if ((rxval == '\r') || (rxval == '\n'))
			{
				if (uart_rx_index > 0)
				{
					uartTX("\r\nReceived '");
					uart_rx_buffer[uart_rx_index] = '\0';
					uartTX(uart_rx_buffer);
					uartTX("'\r\n");
				}

				uart_rx_index = 0;
				
				R_OUT0		= 0;
				R_OUT1		= 0;
				R_OUT2		= 0;
				R_OUT3		= 0;
				R_DIGIT3	= ' ';
				R_DIGIT2	= ' ';
				R_DIGIT1	= ' ';
				R_DIGIT0	= ' ';
			}
			else if (uart_rx_index < 28)
			{
				//   From space (included) to DEL (excluded)
				if ((rxval >= 0x20) && (rxval < 0x7F))
				{
					uart_rx_buffer[uart_rx_index] = rxval;
					uart_rx_index++;

					R_DIGIT3	= ' ';
					R_DIGIT2	= rxval;
					R_DIGIT1	= ' ';
					R_DIGIT0	= ' ';
				}
			}
			else
			{
				uartTX("too long command, resetting\r\n");
				uart_rx_index = 0;
			}
		}
	}
}
