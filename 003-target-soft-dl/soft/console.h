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
// Supported features:
//
// press enter         : execute the current command
// press CTRL+C        : don't execute the current command, don't save to history but preserve on screen
// press ESC twice     : clean current line and don't save to history (the command is not preserved on screen)
// first char is #     : current command is commented out, not executed but saved to history
// line edit           : home, end, cancel, backspace, left and right arrows
//
// Optional fetures:
// press insert        : toggle 'insert'/'overwrite' modes (CONSOLE_INS_MODE    required)
// press arrow up/down : recall history items              (CONSOLE_MAX_HISTORY required)

///////////////////////////////////////////////////////////
// Console definitions

// Prompt string
#define CONSOLE_PROMPT					">"

// Maximum number of history commands - it costs 972 bytes of ROM (nearly independent from items count inthe range 2 to 6)
// - set zero to disable history
// - set one  to enable one history item - it costs 437 bytes of ROM
#define CONSOLE_MAX_HISTORY				6

// Maximum length (in bytes) of a command, including parameters
#define CONSOLE_MAX_COMMAND				32

// Console enable insert/overwrite mode (if disabled 'insert' mode is the default) - it costs 234 bytes of ROM
#define CONSOLE_INS_MODE				0

// Console callback user argument - it costs 82 bytes of ROM
#define CONSOLE_CALLBACK_USER_ARG		0

#if (CONSOLE_CALLBACK_USER_ARG != 0)
	typedef void (*CONSOLE_CALLBACK)(unsigned char *Command, void *Arg);
#else
	typedef void (*CONSOLE_CALLBACK)(unsigned char *Command);
#endif

///////////////////////////////////////////////////////////
// Console enumeratives

typedef enum _CONSOLE_STATUS_
{
	CONSOLE_STATUS_IDLE,			// No escape sequence
	CONSOLE_STATUS_ESC,				// Escape sequence start
	CONSOLE_STATUS_5B,				// ESC + [   (VT100 escape sequence start)
	CONSOLE_STATUS_4F,				// ESC + O   ('end' handling for some terminals)
	CONSOLE_STATUS_7E,				// 0x7E after some escape sequences
	
} CONSOLE_STATUS;

#if (CONSOLE_INS_MODE != 0)
typedef enum _CONSOLE_INS_
{
	CONSOLE_INS_INSERT,
	CONSOLE_INS_OVERWRITE
	
} CONSOLE_INS;
#endif

///////////////////////////////////////////////////////////
// Console structures

typedef struct _CONSOLE_COMMAND_
{
	unsigned char			   *command;
	CONSOLE_CALLBACK			callback;

#if (CONSOLE_CALLBACK_USER_ARG != 0)
	void					   *arg;
#endif

	unsigned char			   *help;
	
} CONSOLE_COMMAND;

typedef struct _CONSOLE_CONTEXT_
{
	CONSOLE_STATUS				status;			// Console status

#if (CONSOLE_INS_MODE != 0)
	CONSOLE_INS					insmode;		// Insert char mode
#endif

	unsigned char				current;		// Buffer current insert position
	unsigned char				end;			// Buffer end position

#if (CONSOLE_MAX_HISTORY > 1)
	unsigned char				historyRead;	// History read position
	unsigned char				historyWrite;	// History write position
	unsigned char				history[CONSOLE_MAX_HISTORY][CONSOLE_MAX_COMMAND];
#endif

#if (CONSOLE_MAX_HISTORY > 0)
	unsigned char				historyCount;	// History items count
	unsigned char				historyActive;	// History item on buffer
#endif

	// Registered commands
	const CONSOLE_COMMAND	   *command;
	unsigned char				commandCount;

	// Current command buffer
	unsigned char				buffer[CONSOLE_MAX_COMMAND];
	
} CONSOLE_CONTEXT;

///////////////////////////////////////////////////////////
// Console functions

void ConsoleInit	(CONSOLE_CONTEXT *Ctx, const CONSOLE_COMMAND *Command, unsigned char Count);
void ConsoleAdd		(CONSOLE_CONTEXT *Ctx, unsigned char Byte);
