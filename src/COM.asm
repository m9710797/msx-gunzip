		org #0100

; Check for DOS2
		xor a
		ld b,a
		ld c,a
		ld d,a
		ld e,a
		ld c,6FH	; _DOSVER
		call #0005	; BDOS
		ld hl,TextNeedDos2
		add a,-1
		jp c,ExitWithError
		ld a,b
		cp 2
		jp c,ExitWithError

; Check if there's enough TPA memory available
STACK_SIZE:	equ #0100	; make sure there's room for this much stack
		ld hl,-(MEMORY_END + STACK_SIZE)
		add hl,sp
		ld hl,TextNoMemory
		jp nc,ExitWithError

; Parse CLI
		call ParseCLI
		ld hl,(cli_archivePath)
		ld a,l
		or h
		ld hl,TextUsage
		jp z,ExitWithError

; Print Welcome
		ld a,(cli_quiet)
		or a
		ld hl,TextWelcome
		call z,System_Print

; Print inflating/testing
		ld a,(cli_quiet)
		or a
		jr nz,SkipPrint
		ld hl,(cli_outputPath)
		ld a,l
		or h
		ld hl,TextTesting
		jr z,DoPrint
		ld hl,TextInflating
DoPrint:	call System_Print
		ld hl,(cli_archivePath)
		call System_Print
		ld hl,TextDotDotDot
		call System_Print
SkipPrint:

; Open input file
		ld de,(cli_archivePath)
		ld a,%00000001  ; read only
		ld c,#43	; _OPEN
		call #0005	; BDOS
		call CheckDOSError
		ld a,b
		ld (Reader_fileHandle),a
		call Reader_FillBuffer	; fill buffer with initial content

; Open output file
		ld de,(cli_outputPath)
		ld a,d
		or e
		jr z,NoOutputFile
		ld a,%00000010  ; write only
		ld bc,0 * 256 + #44 ; _CREATE
		call #0005	; BDOS
		call CheckDOSError
		ld a,b
		ld (Writer_fileHandle),a
NoOutputFile:

		call GzipExtract

; Close output file
		call Writer_FlushBuffer
		ld a,(Writer_fileHandle)
		ld b,a
		inc a
		jr z,SkipCloseOutput
		ld c,#45	; _CLOSE
		call #0005	; BDOS
		call CheckDOSError
SkipCloseOutput:

; Close input file
		ld a,(Reader_fileHandle)
		ld b,a
		ld c,#45	; _CLOSE
		call #0005	; BDOS
		jp CheckDOSError
		; -- done -- 

;
; The actual gunzip code
;

GzipExtract:
; Read header
; Header constants
FLAG_HCRC:	equ #02
FLAG_EXTRA:	equ #04
FLAG_NAME:	equ #08
FLAG_COMMENT:	equ #10
FLAG_RESERVED:	equ #20	 ; #E0

		call Reader_PrepareReadBitInline
; Check two signature bytes
		call Reader_Read_DE_fast
		cp 31  ; gzip signature (1)
		ld hl,TextNotGzip
		jp nz,ExitWithError
		call Reader_Read_DE_fast
		cp 139  ; gzip signature (1)
		;ld hl,TextNotGzip  ; hl not changed
		jp nz,ExitWithError

; Check compression algorithm
		call Reader_Read_DE_fast
		cp 8  ; deflate compression ID (1)
		ld hl,TextNotDeflate
		jp nz,ExitWithError

; Read flags
		call Reader_Read_DE_fast
		ld (HeaderFlags),a

; Skip mtime[4], xfl, os
		ld hl,6	
		call Reader_Skip_DE

; Check for unknown flags
		ld a,(HeaderFlags)
		and FLAG_RESERVED
		ld hl,TextUnknownFlag
		jp nz,ExitWithError

; Check and skip extra section
		ld a,(HeaderFlags)
		and FLAG_EXTRA
		jr z,NoSkipExtra
		call Reader_Read_DE_fast
		ld l,a
		call Reader_Read_DE_fast
		ld h,a
		call Reader_Skip_DE
NoSkipExtra:

; Skip name
		ld a,(HeaderFlags)
		and FLAG_NAME
		call nz,SkipZString

; Skip comment
		ld a,(HeaderFlags)
		and FLAG_COMMENT
		call nz,SkipZString

; Skip header CRC
		ld a,(HeaderFlags)
		and FLAG_HCRC
		ld hl,2
		call nz,Reader_Skip_DE

		call Reader_FinishReadBitInline
	
; Actually decompress
		call Inflate_Inflate
	
; Verify the decompressed data
; Read expected values from file
		call Reader_PrepareReadBitInline
		call Reader_Read_DE_fast
		ld l,a	; bits 7-0
		call Reader_Read_DE_fast
		ld h,a	; bits 15-8
		push hl	; expected crc bits 15-0
		call Reader_Read_DE_fast
		ld l,a	; bits 23-16
		call Reader_Read_DE_fast
		ld h,a	; bits 31-24
		push hl; expected crc bits 31-16

		call Reader_Read_DE_fast
		ld l,a	; bits 7-0
		call Reader_Read_DE_fast
		ld h,a	; bits 15-8
		push hl	; expected-size bits 15-0
		call Reader_Read_DE_fast
		ld l,a	; bits 23-16
		call Reader_Read_DE_fast
		ld h,a	; hl = expected-size bits 31-16
		call Reader_FinishReadBitInline

; Verify size
; TODO flush file before verifying
		ld de,(Writer_count + 2) ; de = actual size bits 31-16
		or a
		sbc hl,de
		jr nz,SizeError
		ld hl,(Writer_bufPos)
		ld a,h
		sub OBUFFER >> 8
		ld h,a		; hl = #bytes still in buffer
		ld bc,(Writer_count + 0) ; written size 15-0
		add hl,bc	; hl = actual size  (add cannot overflow)
		pop de		; expected, bits 15-0
		sbc hl,de
SizeError	ld hl,TextSizeError
		jp nz,ExitWithError

; Verify CRC
		ld hl,OBUFFER
		ld bc,(Writer_bufPos)
		ld a,b
		sub h
		ld b,a
		exx
		ld de,(Writer_crc32 + 0)
		ld bc,(Writer_crc32 + 2)
		call nz,Writer_CalculateCRC32

		pop hl	; expected crc bits 31-16
		scf
		adc hl,bc
		jr nz,CrcError
		pop hl	; expected crc bits 15-0
		scf
		adc hl,de
CrcError:	ld hl,TextCrcError
		jp nz,ExitWithError
		ret


; Skip zero-terminated string
SkipZString:	call Reader_Read_DE_fast
		and a
		jr nz,SkipZString
		ret

; a <- DOS error code
CheckDOSError:	and a
		ret z		; 0 -> no error
		ld b,a
		ld de,scratch_buf
		ld c,#66	; _EXPLAIN
		call #0005	; BDOS
		ld hl,scratch_buf
		call System_PrintLn
		jr DosExit

; hl <- message
ExitWithError:	call System_Print
DosExit:	ld bc,1 * 256 + #62	; _TERM
		jp #0005		; BDOS


; variables
HeaderFlags:	db 0



; strings
TextWelcome:	db "Gunzip 1.0 by Grauw", 13, 10, 10, 0
TextInflating:	db "Inflating ", 0
TextTesting:	db "Testing ",0
TextDotDotDot:	db "...", 13, 10, 0
TextNeedDos2:	db "MSX-DOS 2 is required.",13, 10, 0
TextNoMemory:	db "Insufficient TPA space.", 13, 10, 0
TextUsage:	db "Usage: gunzip [options] <archive.gz> <outputfile>", 13, 10
		db 13, 10
		db "Options:", 13, 10
		db "  /q  Quiet mode, suppress messages.", 13, 10
		db 13, 10
		db "If no output file is specified, the archive will be tested.", 13, 10, 0
TextNotGzip:	db "Not a GZIP file.", 13, 10, 0
TextNotDeflate: db "Not compressed with DEFLATE.", 13, 10, 0
TextUnknownFlag:db "Unknown flag.", 13, 10, 0
TextSizeError:	db "Inflated size mismatch.", 13, 10, 0
TextCrcError:	db "Inflated CRC32 mismatch.", 13, 10, 0



	INCLUDE "System.asm"
	INCLUDE "CLI.asm"
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

LiteralTree:	ds VIRTUAL (8 +  5) * (288 - 1)
LiteralTreeEnd:	equ $
DistanceTree:	ds VIRTUAL (8 + 12) * ( 32 - 1)
DistanceTreeEnd:equ $
cli_buffer:	ds VIRTUAL 255	; TODO could be reused once files are opened

VIRTUAL_ALIGN: MACRO ?boundary
		ds VIRTUAL ?boundary - 1 - ($ + ?boundary - 1) % ?boundary
		ENDM

		VIRTUAL_ALIGN 100H
IBUFFER_SIZE:	equ 1000H
IBUFFER:	ds VIRTUAL IBUFFER_SIZE
IBUFFER_END:	equ IBUFFER + IBUFFER_SIZE

		VIRTUAL_ALIGN 100H
OBUFFER_SIZE:	equ 8000H
OBUFFER:	ds VIRTUAL OBUFFER_SIZE
OBUFFER_END:	equ OBUFFER + OBUFFER_SIZE

; scratch area: the same memory reused by various routines
		VIRTUAL_ALIGN 100H
scratch_buf:	ds VIRTUAL 32

MEMORY_END:	equ $
