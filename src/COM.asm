;
; gzip file decompressor
;

	INCLUDE "Macros.asm"

DEBUG: equ 1

	org 100H

IBUFFER_SIZE: equ 1000H
OBUFFER_SIZE: equ 8000H
STACK_SIZE: equ 100H

;
; Program entry point
;
COM_Main:
	jp Application_Main

	INCLUDE "BIOS.asm"
	INCLUDE "System.asm"
	INCLUDE "Application.asm"
	INCLUDE "CLI.asm"
	INCLUDE "Archive.asm"
	INCLUDE "deflate/Inflate.asm"
	INCLUDE "deflate/FixedAlphabets.asm"
	INCLUDE "deflate/DynamicAlphabets.asm"
	INCLUDE "deflate/Reader.asm"
	INCLUDE "deflate/Writer.asm"

	ALIGN 100H
CRC32Table:
	INCLUDE "crctable.asm"

LiteralTree:		ds VIRTUAL 11 * (288 - 1)
DistanceTree:		ds VIRTUAL 11 * (32 - 1)
cli_buffer:		ds VIRTUAL 255

	VIRTUAL_ALIGN 100H
IBUFFER:		ds VIRTUAL IBUFFER_SIZE
IBUFFER_END:		equ IBUFFER + IBUFFER_SIZE
IBUFFER_END_HIGH:	equ IBUFFER_END >> 8

	VIRTUAL_ALIGN 100H
OBUFFER:		ds VIRTUAL OBUFFER_SIZE
OBUFFER_END:		equ OBUFFER + OBUFFER_SIZE
OBUFFER_END_HIGH:	equ OBUFFER_END >> 8

	VIRTUAL_ALIGN 100H
scratch_buf:		ds VIRTUAL 32

MEMORY_END:		equ $
