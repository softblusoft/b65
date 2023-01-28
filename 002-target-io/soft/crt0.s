; Copyright 2023 Luca Bertossi
;
; This file is part of B65.
; 
;     B65 is free software: you can redistribute it and/or modify
;     it under the terms of the GNU General Public License as published by
;     the Free Software Foundation, either version 3 of the License, or
;     (at your option) any later version.
; 
;     B65 is distributed in the hope that it will be useful,
;     but WITHOUT ANY WARRANTY; without even the implied warranty of
;     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;     GNU General Public License for more details.
; 
;     You should have received a copy of the GNU General Public License
;     along with B65.  If not, see <http://www.gnu.org/licenses/>.

; this file is a modified version from the guide at https://cc65.github.io/doc/customizing.html

; ---------------------------------------------------------------------------
; crt0.s
; ---------------------------------------------------------------------------
;
; Startup code for b65

.export   _init, _exit
.import   _main

.export   __STARTUP__ : absolute = 1        ; Mark as startup
.import   __RAM_START__, __RAM_SIZE__       ; Linker generated
.import   __STACKSIZE__                     ; Linker generated

.import    copydata, zerobss, initlib, donelib

.include  "zeropage.inc"

; ---------------------------------------------------------------------------
; Place the startup code in a special segment

.segment  "STARTUP"

; ---------------------------------------------------------------------------
; CPU entry point

_init:    CLD                          ; Clear decimal mode

          ; Set stack
          LDA     #<(__RAM_START__ + __RAM_SIZE__ + __STACKSIZE__)
          LDX     #>(__RAM_START__ + __RAM_SIZE__ + __STACKSIZE__)
          STA     sp
          STX     sp+1

          ; Call initialize functions
          JSR     zerobss              ; Clear BSS segment
          JSR     copydata             ; Initialize DATA segment
          JSR     initlib              ; Run constructors

          ; Call main()
          JSR     _main

_exit:    JSR     donelib              ; Run destructors

          ; halt CPU
cpu_halt: JMP cpu_halt
