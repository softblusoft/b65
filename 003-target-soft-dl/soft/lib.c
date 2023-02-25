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

///////////////////////////////////////////////////////////
// Functions

///////////////////////////////////////////////////////////
///
/// Convert a Hex string starting with 0x to short integer
///
///	\param	Hex				:	Hex string
///	\param	buf				:	Pointer to input string after hex string
///								(with eventual spaces removed)
///
/// \return unsigned short	:	converted short value
///
///////////////////////////////////////////////////////////
unsigned short HexToNum(unsigned char *Hex, unsigned char **buf)
{
	unsigned short	Value	= 0;
	unsigned char	Byte	= 16;
	unsigned char	Index	= 2;

	if ((Hex[0] != '0') || ((Hex[1] != 'x') && (Hex[1] != 'X')))
		return 0;

	while (Hex[Index] > ' ')
	{
		Byte -= 4;
		if (Hex[Index] <= '9')
			Value |= (Hex[Index] - '0') << Byte;
		else
			Value |= (Hex[Index] - '7') << Byte;

		Index++;
	}

	while (Hex[Index] == ' ')
		Index++;

	if (buf)
		*buf = &Hex[Index];

	return Value >> Byte;
}
