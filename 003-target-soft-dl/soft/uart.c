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

#include "extension.h"

///////////////////////////////////////////////////////////
// Functions

///////////////////////////////////////////////////////////
///
/// Put a char to the UART
///
///	\param	ch : char to write to the UART
///
///////////////////////////////////////////////////////////
void uartPutchar(const unsigned char ch)
{
	R_TX = ch;
}

///////////////////////////////////////////////////////////
///
/// Put a string to the UART
///
///	\param	st : string to write to the UART
///
///////////////////////////////////////////////////////////
void uartPutstring(const unsigned char *st)
{
	while(*st)
	{
		R_TX = *st;
		++st;
	}
}

///////////////////////////////////////////////////////////
///
/// Put a hex byte to the UART (without 0x or any other prefix
///
///	\param	Byte : Byte to write to the UART
///
///////////////////////////////////////////////////////////
void uartPutHexByte(const unsigned char Byte)
{
	unsigned char Hi = (Byte  >> 4) & 0x0F;
	unsigned char Lo = Byte & 0x0F;

	// 7 is ascii 55, adding +10 = 65 i.e. 'A'
	R_TX = ((Hi <= 9)  ? '0' : '7') + Hi;
	R_TX = ((Lo <= 9)  ? '0' : '7') + Lo;
}
