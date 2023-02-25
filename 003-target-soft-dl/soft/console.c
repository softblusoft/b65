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

#include <stdlib.h>
#include <string.h>

#include "uart.h"
#include "console.h"

///////////////////////////////////////////////////////////
// Portability layer

#define CONSOLE_MEMSET					memset
#define CONSOLE_MEMCPY					memcpy
#define CONSOLE_STRLEN					strlen
#define CONSOLE_STRNCMP					strncmp

#define CONSOLE_PUTSTRING				uartPutstring
#define CONSOLE_PUTCHAR					uartPutchar

///////////////////////////////////////////////////////////
// Console escape sequences

// Escape sequences
#define CONSOLE_NEWLINE					"\r\n"
#define CONSOLE_CLEAR_LINE_FROM_CURSOR	"\033[K"
#define CONSOLE_MOVE_RIGHT				"\033[C\0"
#define CONSOLE_MOVE_LEFT				"\033[D\0"

// Ins mode
#define CONSOLE_CURSOR_UNDERLINE		"\033[3 q\0"	// Overwrite
#define CONSOLE_CURSOR_BAR				"\033[5 q\0"	// Insert

///////////////////////////////////////////////////////////
// Console enumeratives

typedef enum _CONSOLE_CONTROL_
{
	CONSOLE_CTRL_ENTER,
	CONSOLE_CTRL_BREAK,				// CTRL + C
	CONSOLE_CTRL_EOF,				// CTRL + D (do nothing)
	CONSOLE_CTRL_BACKSPACE,
	CONSOLE_CTRL_CLEAR_LINE,		// Two consecutive ESC (special handling, clear current line)
	CONSOLE_CTRL_END,
	CONSOLE_CTRL_HOME,
	CONSOLE_CTRL_INSERT,
	CONSOLE_CTRL_CANCEL,
	CONSOLE_CTRL_PAGE_UP,			// do nothing
	CONSOLE_CTRL_PAGE_DOWN,			// do nothing
	CONSOLE_CTRL_ARROW_UP,
	CONSOLE_CTRL_ARROW_DOWN,
	CONSOLE_CTRL_ARROW_RIGHT,
	CONSOLE_CTRL_ARROW_LEFT
	
} CONSOLE_CONTROL;

///////////////////////////////////////////////////////////
// Console static

///////////////////////////////////////////////////////////
///
/// send the prompt
///
///	\param	Ctx		:	Console context
///
///////////////////////////////////////////////////////////
#if (CONSOLE_INS_MODE == 0)
#pragma warn (unused-param, push, off)
#endif
static void ConsolePrompt(CONSOLE_CONTEXT *Ctx)
{
#if (CONSOLE_INS_MODE != 0)
	switch (Ctx->insmode)
	{
		case CONSOLE_INS_INSERT:	CONSOLE_PUTSTRING(CONSOLE_CURSOR_BAR);			break;
		case CONSOLE_INS_OVERWRITE:	CONSOLE_PUTSTRING(CONSOLE_CURSOR_UNDERLINE);	break;
	}
#else
	CONSOLE_PUTSTRING(CONSOLE_CURSOR_BAR);
#endif

	CONSOLE_PUTSTRING(CONSOLE_NEWLINE CONSOLE_PROMPT);
}
#if (CONSOLE_INS_MODE == 0)
#pragma warn (unused-param, pop)
#endif

///////////////////////////////////////////////////////////
///
/// Move the cursor left of Count characters 
///
///	\param	Count	:	Number of chars to move left
///
///////////////////////////////////////////////////////////
static void ConsoleMoveLeft(unsigned char Count)
{
	while (Count--)
		CONSOLE_PUTSTRING(CONSOLE_MOVE_LEFT);
}

///////////////////////////////////////////////////////////
///
/// Move the cursor right of Count characters 
///
///	\param	Count	:	Number of chars to move right
///
///////////////////////////////////////////////////////////
static void ConsoleMoveRight(unsigned char Count)
{
	while (Count--)
		CONSOLE_PUTSTRING(CONSOLE_MOVE_RIGHT);
}

#if (CONSOLE_MAX_HISTORY > 1)
///////////////////////////////////////////////////////////
///
/// Save the current buffer to the history
///
///	\param	Ctx		:	Console context
///
///////////////////////////////////////////////////////////
static void ConsoleHistoryWrite(CONSOLE_CONTEXT *Ctx)
{
	CONSOLE_MEMCPY(Ctx->history[Ctx->historyWrite], Ctx->buffer, Ctx->end + 1);

	Ctx->historyRead = Ctx->historyWrite;

	Ctx->historyWrite++;
	if (Ctx->historyWrite == CONSOLE_MAX_HISTORY)
		Ctx->historyWrite = 0;

	if (Ctx->historyCount < CONSOLE_MAX_HISTORY)
		Ctx->historyCount++;
}

///////////////////////////////////////////////////////////
///
/// Read the current history buffer
///
///	\param	Ctx		:	Console context
///	\param	Dir		:	History read direction
///						- CONSOLE_CTRL_ARROW_UP
///						- CONSOLE_CTRL_ARROW_DOWN
///
/// \return char*	:	Current history buffer or 0 if none
///
///////////////////////////////////////////////////////////
static unsigned char* ConsoleHistoryRecall(CONSOLE_CONTEXT *Ctx, unsigned char Dir)
{
	unsigned char *Buf;

	if (Ctx->historyCount == 0)
		return 0;

	if (Ctx->historyActive)
	{
		if (Dir == CONSOLE_CTRL_ARROW_DOWN)
		{
			Ctx->historyRead++;
			if (Ctx->historyRead == Ctx->historyCount)
				Ctx->historyRead = 0;	
		}
		else
		{
			if (Ctx->historyRead == 0)
				Ctx->historyRead = Ctx->historyCount-1;
			else
				Ctx->historyRead--;
		}
	}

	Buf = Ctx->history[Ctx->historyRead];

	Ctx->historyActive = 1;
	return Buf;
}
#endif // (CONSOLE_MAX_HISTORY > 1)

#if (CONSOLE_MAX_HISTORY > 0)
///////////////////////////////////////////////////////////
///
/// Set the indicated buffer as the current one
///
///	\param	Ctx		:	Console context
///	\param	Buffer	:	Buffer to set as the current one
///
///////////////////////////////////////////////////////////
static void ConsoleSetBuffer(CONSOLE_CONTEXT *Ctx, unsigned char *Buffer)
{
	unsigned char Len;

	if (Buffer == 0)
		return;

	// Reset terminal
	if (Ctx->current > 0)
		ConsoleMoveLeft(Ctx->current);

	// Set new buffer
	Len = CONSOLE_STRLEN(Buffer);
	if (Buffer != Ctx->buffer)
	{
		CONSOLE_MEMCPY(Ctx->buffer, Buffer, Len);
		Ctx->buffer[Len] = '\0';
	}

	Ctx->current	= Len;
	Ctx->end		= Len;

	// Update terminal
	CONSOLE_PUTSTRING(CONSOLE_CLEAR_LINE_FROM_CURSOR);
	CONSOLE_PUTSTRING(Ctx->buffer);
}
#endif // (CONSOLE_MAX_HISTORY > 0)

///////////////////////////////////////////////////////////
///
/// Insert a new character in the command buffer
///
///	\param	Ctx		:	Console context
///	\param	Byte	:	New received byte
///
///////////////////////////////////////////////////////////
static void ConsoleInsert(CONSOLE_CONTEXT *Ctx, unsigned char Byte)
{
	unsigned char Index = Ctx->end;

#if (CONSOLE_INS_MODE != 0)
	if (Ctx->insmode == CONSOLE_INS_INSERT)
#endif
	{
		if (Index > CONSOLE_MAX_COMMAND - 1)
			Index = CONSOLE_MAX_COMMAND - 1;

		// Make room for a char (if due)
		while (Ctx->current < Index)
		{
			Ctx->buffer[Index] = Ctx->buffer[Index-1];
			Index--;
		}
	}

	// Add one char
	Ctx->buffer[Ctx->current] = Byte;
	if (Ctx->current < CONSOLE_MAX_COMMAND)
	{
	#if (CONSOLE_INS_MODE != 0)
		if ((Ctx->insmode == CONSOLE_INS_INSERT) || (Ctx->current == Ctx->end))
	#endif
			Ctx->end++;

		Ctx->current++;
	}
	
	// Adjust the terminal
#if (CONSOLE_INS_MODE != 0)
	if ((Ctx->insmode == CONSOLE_INS_INSERT) && (Ctx->current != Ctx->end))
#else
	if (Ctx->current != Ctx->end)
#endif
	{
		Ctx->buffer[Ctx->end] = '\0';
		CONSOLE_PUTSTRING(CONSOLE_CLEAR_LINE_FROM_CURSOR);
		CONSOLE_PUTSTRING(&Ctx->buffer[Ctx->current-1]);
		ConsoleMoveLeft(Ctx->end - Ctx->current);
	}
	else
		CONSOLE_PUTCHAR(Byte);
	
	#if (CONSOLE_MAX_HISTORY > 0)
		Ctx->historyActive = 0;
	#endif
}

///////////////////////////////////////////////////////////
///
/// Remove the left character from the command buffer
///
///	\param	Ctx		:	Console context
///
///////////////////////////////////////////////////////////
static void ConsoleBackspace(CONSOLE_CONTEXT *Ctx)
{
	unsigned char Index;

	if ((Ctx->current > 0) && (Ctx->current <= Ctx->end))
	{
		CONSOLE_PUTSTRING(CONSOLE_MOVE_LEFT);
		CONSOLE_PUTSTRING(CONSOLE_CLEAR_LINE_FROM_CURSOR);

		Index = Ctx->current - 1;
		while (Index < Ctx->end)
		{
			Ctx->buffer[Index] = Ctx->buffer[Index+1];
			Index++;
		}

		Ctx->end--;
		Ctx->current--;
		Ctx->buffer[Ctx->end] = '\0';

		CONSOLE_PUTSTRING(&Ctx->buffer[Ctx->current]);
		if (Ctx->current < Ctx->end)
			ConsoleMoveLeft(Ctx->end - Ctx->current);
	}
}

///////////////////////////////////////////////////////////
///
/// Remove the right character from the command buffer
///
///	\param	Ctx		:	Console context
///
///////////////////////////////////////////////////////////
static void ConsoleCancel(CONSOLE_CONTEXT *Ctx)
{
	unsigned char Index;

	if ((Ctx->end > 0) && (Ctx->current < Ctx->end))
	{
		CONSOLE_PUTSTRING(CONSOLE_CLEAR_LINE_FROM_CURSOR);

		Index = Ctx->current;
		while (Index < Ctx->end)
		{
			Ctx->buffer[Index] = Ctx->buffer[Index+1];
			Index++;
		}

		if (Ctx->end > 0)
			Ctx->end--;
	
		Ctx->buffer[Ctx->end] = '\0';

		CONSOLE_PUTSTRING(&Ctx->buffer[Ctx->current]);
		ConsoleMoveLeft(Ctx->end - Ctx->current);

		if (Ctx->current > 0)
			Ctx->current--;
	}
}

///////////////////////////////////////////////////////////
///
/// Execute the command buffer
///
///	\param	Ctx		:	Console context
///
///////////////////////////////////////////////////////////
static void ConsoleExecute(CONSOLE_CONTEXT *Ctx)
{
	unsigned char Done = 0;
	unsigned char Index;
	unsigned char Len;
	
	if (Ctx->end != 0)
	{
		Ctx->buffer[Ctx->end]				= '\0';
		Ctx->buffer[CONSOLE_MAX_COMMAND-1]	= '\0';

		// If not commented out, execute
		if (Ctx->buffer[0] != '#')
		{
			for (Index = 0; Index < Ctx->commandCount; Index++)
			{
				Len = CONSOLE_STRLEN(Ctx->command[Index].command);
				if ((CONSOLE_STRNCMP(Ctx->command[Index].command, Ctx->buffer, Len) == 0) && Ctx->command[Index].callback)
				{
					CONSOLE_PUTSTRING(CONSOLE_NEWLINE);

				#if (CONSOLE_CALLBACK_USER_ARG != 0)
					Ctx->command[Index].callback(Ctx->buffer,  Ctx->command[Index].arg);
				#else
					Ctx->command[Index].callback(Ctx->buffer);
				#endif

					Done = 1;
					break;
				}
			}

			if (Done == 0)
			{
				CONSOLE_PUTSTRING(CONSOLE_NEWLINE "  ERROR : command [");
				CONSOLE_PUTSTRING(Ctx->buffer);
				CONSOLE_PUTSTRING("] not found");
			}
			#if (CONSOLE_MAX_HISTORY > 0)
			else 
			{
				// Write History
				if (Ctx->historyActive == 0)
				#if (CONSOLE_MAX_HISTORY > 1)
					ConsoleHistoryWrite(Ctx);
				#else
					Ctx->historyCount = 1;
				#endif
				Ctx->historyActive = 0;
			}
			#endif
		}
	}

	// Reset buffer
	Ctx->current	= 0;
	Ctx->end		= 0;

	// Draw prompt
	ConsolePrompt(Ctx);
}

///////////////////////////////////////////////////////////
///
/// Handle a control character 
///
///	\param	Ctx		:	Console context
///	\param	Ctrl	:	Received control char
///
///////////////////////////////////////////////////////////
static void ConsoleControlChar(CONSOLE_CONTEXT *Ctx, CONSOLE_CONTROL Ctrl)
{
	switch (Ctrl)
	{
		case CONSOLE_CTRL_ENTER:
			ConsoleExecute(Ctx);
		break;

		case CONSOLE_CTRL_BREAK:
			Ctx->current	= 0;
			Ctx->end		= 0;
			ConsolePrompt(Ctx);
		break;

	//	case CONSOLE_CTRL_EOF:			break;
	
		case CONSOLE_CTRL_BACKSPACE:
			ConsoleBackspace(Ctx);
		break;	
		
		case CONSOLE_CTRL_CLEAR_LINE:
			if (Ctx->current > 0)
				ConsoleMoveLeft(Ctx->current);
			CONSOLE_PUTSTRING(CONSOLE_CLEAR_LINE_FROM_CURSOR);
			Ctx->current	= 0;
			Ctx->end		= 0;
		break;

		case CONSOLE_CTRL_END:
			if (Ctx->current < Ctx->end)
			{
				ConsoleMoveRight(Ctx->end - Ctx->current);
				Ctx->current = Ctx->end;
			}
		break;
		
		case CONSOLE_CTRL_HOME:
			if (Ctx->current > 0)
			{
				ConsoleMoveLeft(Ctx->current);
				Ctx->current = 0;
			}
		break;
		
#if (CONSOLE_INS_MODE != 0)
		// Insert or overwrite mode
		case CONSOLE_CTRL_INSERT:
			switch(Ctx->insmode)
			{
				case CONSOLE_INS_INSERT:	Ctx->insmode = CONSOLE_INS_OVERWRITE;	CONSOLE_PUTSTRING(CONSOLE_CURSOR_UNDERLINE);	break;
				case CONSOLE_INS_OVERWRITE:	Ctx->insmode = CONSOLE_INS_INSERT;		CONSOLE_PUTSTRING(CONSOLE_CURSOR_BAR);			break;
			}
		break;		
#endif

		case CONSOLE_CTRL_CANCEL:
			ConsoleCancel(Ctx);
		break;

	//	case CONSOLE_CTRL_PAGE_UP:		break;
	//	case CONSOLE_CTRL_PAGE_DOWN:	break;

	#if (CONSOLE_MAX_HISTORY > 0)
		case CONSOLE_CTRL_ARROW_UP:
		case CONSOLE_CTRL_ARROW_DOWN:
			#if (CONSOLE_MAX_HISTORY > 1)
				ConsoleSetBuffer(Ctx, ConsoleHistoryRecall(Ctx, Ctrl));
			#else
				Ctx->historyActive = 1;
				ConsoleSetBuffer(Ctx, Ctx->buffer);
			#endif
		break;
	#endif

		case CONSOLE_CTRL_ARROW_LEFT:
			if (Ctx->current > 0)
			{
				Ctx->current--;
				CONSOLE_PUTSTRING(CONSOLE_MOVE_LEFT);
			}
		break;

		case CONSOLE_CTRL_ARROW_RIGHT:
			if (Ctx->current < Ctx->end)
			{
				Ctx->current++;
				CONSOLE_PUTSTRING(CONSOLE_MOVE_RIGHT);
			}
		break;
	}
	
	#if (CONSOLE_MAX_HISTORY > 0)
	if ((Ctrl != CONSOLE_CTRL_ARROW_UP) && (Ctrl != CONSOLE_CTRL_ARROW_DOWN))
		Ctx->historyActive = 0;
	#endif
}

///////////////////////////////////////////////////////////
// Console functions

///////////////////////////////////////////////////////////
///
/// Initialize the console
///
///	\param	Ctx			:	Console context
///	\param	Command		:	Array of recognized commands
///	\param	Count		:	Number of items in the commands array
///
///////////////////////////////////////////////////////////
void ConsoleInit(CONSOLE_CONTEXT *Ctx, const CONSOLE_COMMAND *Command, unsigned char Count)
{
	CONSOLE_MEMSET(Ctx, 0, sizeof(CONSOLE_CONTEXT));

	Ctx->command		= Command;
	Ctx->commandCount	= Count;
	
	ConsolePrompt(Ctx);
}

///////////////////////////////////////////////////////////
///
/// Called when new char is received
///
///	\param	Ctx		:	Console context
///	\param	Byte	:	New received byte
///
///	\note	Recognized escape chars:
///				- up arrow		= 0x1b 0x5b 0x41		Read previous command from history
///				- down arrow	= 0x1b 0x5b 0x42		Read next command from history
///				- right arrow	= 0x1b 0x5b 0x43		move one char right up to the end of line
///				- left arrow	= 0x1b 0x5b 0x44		move one char left up to the begin of line
///				- end			= 0x1b 0x4f 0x46
///								  0x1b 0x5b 0x34 0x7e	go to the end of line
///				- Page Up		= 0x1b 0x5b 0x35 0x7e	<not used in this console>
///				- Page Down		= 0x1b 0x5b 0x36 0x7e	<not used in this console>
///				- home			= 0x1b 0x5b 0x31 0x7e	go home
///				- canc			= 0x1b 0x5b 0x33 0x7e	clear right char
///				- ins			= 0x1b 0x5b 0x32 0x7e	<not used in this console>
///				- backspace		= 0x08 or 0x7F			clear left char
///				- enter			= 0x0d					execute command
///				- CTRL+C		= 0x03					cancel current command and new prompt
///				- CTRL+D		= 0x04					<not used in this console>
///				- ESC			= 0x1b					repeated twice, clear current line
///
/// \note	0x7e at the sequence end comes before the next sent char
///			and it could be not closed to the escape sequence, it's filtered
///
///			Backspace could be 0x08 or 0x7F depending on terminal
///
///			Two consecutive ESC clear the current line
///
///////////////////////////////////////////////////////////
void ConsoleAdd(CONSOLE_CONTEXT *Ctx, unsigned char Byte)
{
	unsigned char Set7E = 0;

	// Command character
	if ((Ctx->status == CONSOLE_STATUS_IDLE) && (Byte >= 0x20) && (Byte < 0x7F))
		ConsoleInsert(Ctx, Byte);
	
	if       (Byte == 0x0D)											ConsoleControlChar(Ctx, CONSOLE_CTRL_ENTER);
	else if  (Byte == 0x03)											ConsoleControlChar(Ctx, CONSOLE_CTRL_BREAK);
	else if  (Byte == 0x04)											ConsoleControlChar(Ctx, CONSOLE_CTRL_EOF);
	else if ((Byte == 0x08) || (Byte == 0x7F))						ConsoleControlChar(Ctx, CONSOLE_CTRL_BACKSPACE);
	else if  (Byte == 0x18)											ConsoleControlChar(Ctx, CONSOLE_CTRL_CANCEL);
	else if ((Ctx->status == CONSOLE_STATUS_ESC) && (Byte == 0x1B))	ConsoleControlChar(Ctx, CONSOLE_CTRL_CLEAR_LINE);
	else if ((Ctx->status == CONSOLE_STATUS_4F ) && (Byte == 0x46))	ConsoleControlChar(Ctx, CONSOLE_CTRL_END);
	else if  (Ctx->status == CONSOLE_STATUS_5B)
	{
		switch (Byte)
		{
			case 0x31: ConsoleControlChar(Ctx, CONSOLE_CTRL_HOME);		Set7E = CONSOLE_STATUS_7E;	break;
			case 0x32: ConsoleControlChar(Ctx, CONSOLE_CTRL_INSERT);	Set7E = CONSOLE_STATUS_7E;	break;
			case 0x33: ConsoleControlChar(Ctx, CONSOLE_CTRL_CANCEL);	Set7E = CONSOLE_STATUS_7E;	break;
			case 0x34: ConsoleControlChar(Ctx, CONSOLE_CTRL_END);		Set7E = CONSOLE_STATUS_7E;	break;
			case 0x35: ConsoleControlChar(Ctx, CONSOLE_CTRL_PAGE_UP);	Set7E = CONSOLE_STATUS_7E;	break;
			case 0x36: ConsoleControlChar(Ctx, CONSOLE_CTRL_PAGE_DOWN);	Set7E = CONSOLE_STATUS_7E;	break;

			case 0x41: ConsoleControlChar(Ctx, CONSOLE_CTRL_ARROW_UP);								break;
			case 0x42: ConsoleControlChar(Ctx, CONSOLE_CTRL_ARROW_DOWN);							break;
			case 0x43: ConsoleControlChar(Ctx, CONSOLE_CTRL_ARROW_RIGHT);							break;
			case 0x44: ConsoleControlChar(Ctx, CONSOLE_CTRL_ARROW_LEFT);							break;
		}
	}

	// Update the status
		 if ((Byte == 0x1B) && (Ctx->status == CONSOLE_STATUS_IDLE))	{ Ctx->status = CONSOLE_STATUS_ESC;		}
	else if ((Byte == 0x5B) && (Ctx->status == CONSOLE_STATUS_ESC ))	{ Ctx->status = CONSOLE_STATUS_5B;		}
	else if ((Byte == 0x4F) && (Ctx->status == CONSOLE_STATUS_ESC ))	{ Ctx->status = CONSOLE_STATUS_4F;		}
	else																{ Ctx->status = CONSOLE_STATUS_IDLE;	}

	if (Set7E)
		Ctx->status = CONSOLE_STATUS_7E;
}
