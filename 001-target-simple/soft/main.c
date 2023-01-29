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

// Define memory locations used to verify VHDL simulation
#define TESTREG	 (*(unsigned char*) 0x0240)

// Entry point
void main(void)
{
	unsigned char delay = 0;
	unsigned char count = 0;

	// Enable interrupt (otherwise cpu_irq signal has no effects on software)
	asm("cli");

	TESTREG = 0xBB;

	while(1)
	{
		for (delay = 0; delay < 16; delay++)
			;

		TESTREG = count;
		count++;
	}
}
