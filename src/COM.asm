; macros
ALIGN: MACRO ?boundary
	ds ?boundary - 1 - ($ + ?boundary - 1) % ?boundary
	ENDM

VIRTUAL_ALIGN: MACRO ?boundary
	ds VIRTUAL ?boundary - 1 - ($ + ?boundary - 1) % ?boundary
	ENDM


DEBUG: equ 1

	org 100H

IBUFFER_SIZE: equ 1000H
OBUFFER_SIZE: equ 8000H
STACK_SIZE: equ 100H

;
; Program entry point
;
COM_Main:
	INCLUDE "Application.asm"
	INCLUDE "System.asm"
	INCLUDE "CLI.asm"
	INCLUDE "Archive.asm"
	INCLUDE "deflate/Inflate.asm"
	INCLUDE "deflate/FixedAlphabets.asm"
	INCLUDE "deflate/DynamicAlphabets.asm"
	INCLUDE "deflate/Reader.asm"
	INCLUDE "deflate/Writer.asm"
code_end:

	ALIGN 100H
CRC32Table:
	INCLUDE "crctable.asm"

LiteralTree:		ds VIRTUAL (8 +  5) * (288 - 1)
LiteralTreeEnd:		equ $
DistanceTree:		ds VIRTUAL (8 + 12) * ( 32 - 1)
DistanceTreeEnd:	equ $
cli_buffer:		ds VIRTUAL 255	; TODO could be reused once files are opened

	VIRTUAL_ALIGN 100H
IBUFFER:		ds VIRTUAL IBUFFER_SIZE
IBUFFER_END:		equ IBUFFER + IBUFFER_SIZE
IBUFFER_END_HIGH:	equ IBUFFER_END >> 8

	VIRTUAL_ALIGN 100H
OBUFFER:		ds VIRTUAL OBUFFER_SIZE
OBUFFER_END:		equ OBUFFER + OBUFFER_SIZE
OBUFFER_END_HIGH:	equ OBUFFER_END >> 8

; scratch area: the same memory reused by various routines
	VIRTUAL_ALIGN 100H
scratch_buf:		ds VIRTUAL 32

MEMORY_END:		equ $
