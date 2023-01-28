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

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// ROM to COE file converter
int main(int argc, char **argv)
{
	int		DataWidth	= 8;
	int		LineIndex	= 0;
	int		LineChar	= 0;
	size_t	Index		= 0;
	size_t	Length;
	size_t	FileSize;
	char	CoeFilename[255];
	char	*InBuffer;
	char	OutLine[1024];
	FILE	*File;

	if (argc < 2)
	{
		printf("Usage : \n");
		printf("rom2coe <input bin file> [data width]\n");
		printf(" Optional data width can be 8 (default), 16 or 32 bit\n");
		return 0;
	}
	
	if (argc > 2)
	{
		DataWidth = strtol(argv[2], NULL, 0);
		if ((DataWidth != 8) && (DataWidth != 16) && (DataWidth != 32))
		{
			printf("Error: unsupported data width [%d], only 8,16 or 32 supported\n", DataWidth);
			return 1;
		}
	}

	File = fopen(argv[1], "r");
	if (File == NULL)
	{
		printf("Error: unable to open [%s]\n", argv[1]);
		return 2;
	}
	
	// Get file size
	fseek(File, 0, SEEK_END);
	FileSize = ftell(File);
	fseek(File, 0, 0);
	
	// Allocate buffer
	InBuffer = malloc(FileSize);
	if (InBuffer == NULL)
	{
		printf("Error: unable to allocate [%d] bytes\n", (int) FileSize);
		fclose(File);
		return 3;
	}

	// Load file	
	fread(InBuffer, FileSize, 1, File);
	fclose(File);
	
	// Remove 3 chars bin extension and append coe extension
	strncpy(CoeFilename, argv[1], 255);
	Length = strlen(CoeFilename);
	CoeFilename[Length-3] = '\0';
	strcat(CoeFilename, "coe");

	// Open output file
	File = fopen(CoeFilename, "w+");
	if (File == NULL)
	{
		printf("Error: unable to create [%s]\n", CoeFilename);
		free(InBuffer);
		return 4;
	}

	// printf("Converting [%d] bytes ROM file [%s] to [%d] bit width COE [%s]\n", (int) FileSize, argv[1], DataWidth, CoeFilename);
	
	fprintf(File, "memory_initialization_radix=16;\n");
	fprintf(File, "memory_initialization_vector=\n");

	while (Index < FileSize)
	{
		switch (DataWidth)
		{
			case  8: LineIndex += sprintf(&OutLine[LineIndex], "%.2X, ",             InBuffer[Index]  & 0x000000FF); Index += 1; break;
			case 16: LineIndex += sprintf(&OutLine[LineIndex], "%.4X, ", *((short*) &InBuffer[Index]) & 0x0000FFFF); Index += 2; break;
			case 32: LineIndex += sprintf(&OutLine[LineIndex], "%.8X, ", *((int  *) &InBuffer[Index]));              Index += 4; break;
		}

		LineChar++;
		if (LineChar == 16)
		{
			OutLine[LineIndex - 2]  = '\n';
			OutLine[LineIndex - 1]  = '\0';
			fputs(OutLine, File);
			LineChar	= 0;
			LineIndex	= 0;
		}
	}

	if (LineIndex > 2)
	{
		OutLine[LineIndex - 2]  = '\n';
		OutLine[LineIndex - 1]  = '\0';
		fputs(OutLine, File);
	}

	fclose(File);
	free(InBuffer);
	return 0;
}