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
