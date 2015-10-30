;
; Application
;
; gzip file decompressor
;

	INCLUDE "Macros.asm"

DEBUG: equ 1

	org 100H

IBUFFER_SIZE: equ 1000H
OBUFFER_SIZE: equ 8000H
HEAP_SIZE: equ 0400H
STACK_SIZE: equ 100H

TPA: ds 3000H
RAM: ds 0100H
IBUFFER: ds VIRTUAL IBUFFER_SIZE
IBUFFER_END: equ IBUFFER + IBUFFER_SIZE
IBUFFER_END_HIGH: equ IBUFFER_END >> 8
OBUFFER: ds VIRTUAL OBUFFER_SIZE
OBUFFER_END: equ OBUFFER + OBUFFER_SIZE
OBUFFER_END_HIGH: equ OBUFFER_END >> 8
HEAP: ds VIRTUAL HEAP_SIZE

	SECTION TPA

;
; Program entry point
;
COM_Main:
	jp Application_Main

	INCLUDE "DOS.asm"
	INCLUDE "BIOS.asm"
	INCLUDE "System.asm"
	INCLUDE "Heap.asm"
	INCLUDE "Class.asm"
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

	ENDS

	SECTION RAM

Heap_main:
	Heap HEAP, HEAP_SIZE

	ENDS
