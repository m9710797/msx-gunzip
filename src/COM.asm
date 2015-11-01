; macros

VIRTUAL_ALIGN: MACRO ?boundary
	ds VIRTUAL ?boundary - 1 - ($ + ?boundary - 1) % ?boundary
	ENDM


	org 100H

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

; lookup table to speedup crc32 calculations, must be 256-byte aligned
	ds (256 - ($ & 255) & 255)
CRC32Table: ; uint32_t[256]
	; bits 0-7
	db #00, #96, #2c, #ba, #19, #8f, #35, #a3
	db #32, #a4, #1e, #88, #2b, #bd, #07, #91
	db #64, #f2, #48, #de, #7d, #eb, #51, #c7
	db #56, #c0, #7a, #ec, #4f, #d9, #63, #f5
	db #c8, #5e, #e4, #72, #d1, #47, #fd, #6b
	db #fa, #6c, #d6, #40, #e3, #75, #cf, #59
	db #ac, #3a, #80, #16, #b5, #23, #99, #0f
	db #9e, #08, #b2, #24, #87, #11, #ab, #3d
	db #90, #06, #bc, #2a, #89, #1f, #a5, #33
	db #a2, #34, #8e, #18, #bb, #2d, #97, #01
	db #f4, #62, #d8, #4e, #ed, #7b, #c1, #57
	db #c6, #50, #ea, #7c, #df, #49, #f3, #65
	db #58, #ce, #74, #e2, #41, #d7, #6d, #fb
	db #6a, #fc, #46, #d0, #73, #e5, #5f, #c9
	db #3c, #aa, #10, #86, #25, #b3, #09, #9f
	db #0e, #98, #22, #b4, #17, #81, #3b, #ad
	db #20, #b6, #0c, #9a, #39, #af, #15, #83
	db #12, #84, #3e, #a8, #0b, #9d, #27, #b1
	db #44, #d2, #68, #fe, #5d, #cb, #71, #e7
	db #76, #e0, #5a, #cc, #6f, #f9, #43, #d5
	db #e8, #7e, #c4, #52, #f1, #67, #dd, #4b
	db #da, #4c, #f6, #60, #c3, #55, #ef, #79
	db #8c, #1a, #a0, #36, #95, #03, #b9, #2f
	db #be, #28, #92, #04, #a7, #31, #8b, #1d
	db #b0, #26, #9c, #0a, #a9, #3f, #85, #13
	db #82, #14, #ae, #38, #9b, #0d, #b7, #21
	db #d4, #42, #f8, #6e, #cd, #5b, #e1, #77
	db #e6, #70, #ca, #5c, #ff, #69, #d3, #45
	db #78, #ee, #54, #c2, #61, #f7, #4d, #db
	db #4a, #dc, #66, #f0, #53, #c5, #7f, #e9
	db #1c, #8a, #30, #a6, #05, #93, #29, #bf
	db #2e, #b8, #02, #94, #37, #a1, #1b, #8d

	; bits 8-15
	db #00, #30, #61, #51, #c4, #f4, #a5, #95
	db #88, #b8, #e9, #d9, #4c, #7c, #2d, #1d
	db #10, #20, #71, #41, #d4, #e4, #b5, #85
	db #98, #a8, #f9, #c9, #5c, #6c, #3d, #0d
	db #20, #10, #41, #71, #e4, #d4, #85, #b5
	db #a8, #98, #c9, #f9, #6c, #5c, #0d, #3d
	db #30, #00, #51, #61, #f4, #c4, #95, #a5
	db #b8, #88, #d9, #e9, #7c, #4c, #1d, #2d
	db #41, #71, #20, #10, #85, #b5, #e4, #d4
	db #c9, #f9, #a8, #98, #0d, #3d, #6c, #5c
	db #51, #61, #30, #00, #95, #a5, #f4, #c4
	db #d9, #e9, #b8, #88, #1d, #2d, #7c, #4c
	db #61, #51, #00, #30, #a5, #95, #c4, #f4
	db #e9, #d9, #88, #b8, #2d, #1d, #4c, #7c
	db #71, #41, #10, #20, #b5, #85, #d4, #e4
	db #f9, #c9, #98, #a8, #3d, #0d, #5c, #6c
	db #83, #b3, #e2, #d2, #47, #77, #26, #16
	db #0b, #3b, #6a, #5a, #cf, #ff, #ae, #9e
	db #93, #a3, #f2, #c2, #57, #67, #36, #06
	db #1b, #2b, #7a, #4a, #df, #ef, #be, #8e
	db #a3, #93, #c2, #f2, #67, #57, #06, #36
	db #2b, #1b, #4a, #7a, #ef, #df, #8e, #be
	db #b3, #83, #d2, #e2, #77, #47, #16, #26
	db #3b, #0b, #5a, #6a, #ff, #cf, #9e, #ae
	db #c2, #f2, #a3, #93, #06, #36, #67, #57
	db #4a, #7a, #2b, #1b, #8e, #be, #ef, #df
	db #d2, #e2, #b3, #83, #16, #26, #77, #47
	db #5a, #6a, #3b, #0b, #9e, #ae, #ff, #cf
	db #e2, #d2, #83, #b3, #26, #16, #47, #77
	db #6a, #5a, #0b, #3b, #ae, #9e, #cf, #ff
	db #f2, #c2, #93, #a3, #36, #06, #57, #67
	db #7a, #4a, #1b, #2b, #be, #8e, #df, #ef

	; bits 16-23
	db #00, #07, #0e, #09, #6d, #6a, #63, #64
	db #db, #dc, #d5, #d2, #b6, #b1, #b8, #bf
	db #b7, #b0, #b9, #be, #da, #dd, #d4, #d3
	db #6c, #6b, #62, #65, #01, #06, #0f, #08
	db #6e, #69, #60, #67, #03, #04, #0d, #0a
	db #b5, #b2, #bb, #bc, #d8, #df, #d6, #d1
	db #d9, #de, #d7, #d0, #b4, #b3, #ba, #bd
	db #02, #05, #0c, #0b, #6f, #68, #61, #66
	db #dc, #db, #d2, #d5, #b1, #b6, #bf, #b8
	db #07, #00, #09, #0e, #6a, #6d, #64, #63
	db #6b, #6c, #65, #62, #06, #01, #08, #0f
	db #b0, #b7, #be, #b9, #dd, #da, #d3, #d4
	db #b2, #b5, #bc, #bb, #df, #d8, #d1, #d6
	db #69, #6e, #67, #60, #04, #03, #0a, #0d
	db #05, #02, #0b, #0c, #68, #6f, #66, #61
	db #de, #d9, #d0, #d7, #b3, #b4, #bd, #ba
	db #b8, #bf, #b6, #b1, #d5, #d2, #db, #dc
	db #63, #64, #6d, #6a, #0e, #09, #00, #07
	db #0f, #08, #01, #06, #62, #65, #6c, #6b
	db #d4, #d3, #da, #dd, #b9, #be, #b7, #b0
	db #d6, #d1, #d8, #df, #bb, #bc, #b5, #b2
	db #0d, #0a, #03, #04, #60, #67, #6e, #69
	db #61, #66, #6f, #68, #0c, #0b, #02, #05
	db #ba, #bd, #b4, #b3, #d7, #d0, #d9, #de
	db #64, #63, #6a, #6d, #09, #0e, #07, #00
	db #bf, #b8, #b1, #b6, #d2, #d5, #dc, #db
	db #d3, #d4, #dd, #da, #be, #b9, #b0, #b7
	db #08, #0f, #06, #01, #65, #62, #6b, #6c
	db #0a, #0d, #04, #03, #67, #60, #69, #6e
	db #d1, #d6, #df, #d8, #bc, #bb, #b2, #b5
	db #bd, #ba, #b3, #b4, #d0, #d7, #de, #d9
	db #66, #61, #68, #6f, #0b, #0c, #05, #02

	; bits 24-31
	db #00, #77, #ee, #99, #07, #70, #e9, #9e
	db #0e, #79, #e0, #97, #09, #7e, #e7, #90
	db #1d, #6a, #f3, #84, #1a, #6d, #f4, #83
	db #13, #64, #fd, #8a, #14, #63, #fa, #8d
	db #3b, #4c, #d5, #a2, #3c, #4b, #d2, #a5
	db #35, #42, #db, #ac, #32, #45, #dc, #ab
	db #26, #51, #c8, #bf, #21, #56, #cf, #b8
	db #28, #5f, #c6, #b1, #2f, #58, #c1, #b6
	db #76, #01, #98, #ef, #71, #06, #9f, #e8
	db #78, #0f, #96, #e1, #7f, #08, #91, #e6
	db #6b, #1c, #85, #f2, #6c, #1b, #82, #f5
	db #65, #12, #8b, #fc, #62, #15, #8c, #fb
	db #4d, #3a, #a3, #d4, #4a, #3d, #a4, #d3
	db #43, #34, #ad, #da, #44, #33, #aa, #dd
	db #50, #27, #be, #c9, #57, #20, #b9, #ce
	db #5e, #29, #b0, #c7, #59, #2e, #b7, #c0
	db #ed, #9a, #03, #74, #ea, #9d, #04, #73
	db #e3, #94, #0d, #7a, #e4, #93, #0a, #7d
	db #f0, #87, #1e, #69, #f7, #80, #19, #6e
	db #fe, #89, #10, #67, #f9, #8e, #17, #60
	db #d6, #a1, #38, #4f, #d1, #a6, #3f, #48
	db #d8, #af, #36, #41, #df, #a8, #31, #46
	db #cb, #bc, #25, #52, #cc, #bb, #22, #55
	db #c5, #b2, #2b, #5c, #c2, #b5, #2c, #5b
	db #9b, #ec, #75, #02, #9c, #eb, #72, #05
	db #95, #e2, #7b, #0c, #92, #e5, #7c, #0b
	db #86, #f1, #68, #1f, #81, #f6, #6f, #18
	db #88, #ff, #66, #11, #8f, #f8, #61, #16
	db #a0, #d7, #4e, #39, #a7, #d0, #49, #3e
	db #ae, #d9, #40, #37, #a9, #de, #47, #30
	db #bd, #ca, #53, #24, #ba, #cd, #54, #23
	db #b3, #c4, #5d, #2a, #b4, #c3, #5a, #2d

LiteralTree:		ds VIRTUAL (8 +  5) * (288 - 1)
LiteralTreeEnd:		equ $
DistanceTree:		ds VIRTUAL (8 + 12) * ( 32 - 1)
DistanceTreeEnd:	equ $
cli_buffer:		ds VIRTUAL 255	; TODO could be reused once files are opened

	VIRTUAL_ALIGN 100H
IBUFFER_SIZE:		equ 1000H
IBUFFER:		ds VIRTUAL IBUFFER_SIZE
IBUFFER_END:		equ IBUFFER + IBUFFER_SIZE
IBUFFER_END_HIGH:	equ IBUFFER_END >> 8

	VIRTUAL_ALIGN 100H
OBUFFER_SIZE:		equ 8000H
OBUFFER:		ds VIRTUAL OBUFFER_SIZE
OBUFFER_END:		equ OBUFFER + OBUFFER_SIZE
OBUFFER_END_HIGH:	equ OBUFFER_END >> 8

; scratch area: the same memory reused by various routines
	VIRTUAL_ALIGN 100H
scratch_buf:		ds VIRTUAL 32

MEMORY_END:		equ $
