		org #0100

; -- Main program --

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
StackSize:	equ #0100	; make sure there's room for this much stack
		ld hl,-(MemoryEnd + StackSize)
		add hl,sp
		ld hl,TextNoMemory
		jp nc,ExitWithError

; Parse CLI
		call ParseCLI
		ld hl,(InputPath)
		ld a,l
		or h
		ld hl,TextUsage
		jp z,ExitWithError

; Print Welcome
		ld a,(Quiet)
		or a
		ld hl,TextWelcome
		call z,Print

; Print inflating/testing
		ld a,(Quiet)
		or a
		jr nz,SkipPrint
		ld hl,(OutputPath)
		ld a,l
		or h
		ld hl,TextTesting
		jr z,DoPrint
		ld hl,TextInflating
DoPrint:	call Print
		ld hl,(InputPath)
		call Print
		ld hl,TextDotDotDot
		call Print
SkipPrint:

; Open input file
		ld de,(InputPath)
		ld a,%00000001  ; read only
		ld c,#43	; _OPEN
		call #0005	; BDOS
		call CheckDOSError
		ld a,b
		ld (InFileHandle),a
		call FillInBuffer	; fill buffer with initial content

; Open output file
		ld de,(OutputPath)
		ld a,d
		or e
		jr z,NoOutputFile
		ld a,%00000010  ; write only
		ld bc,0 * 256 + #44 ; _CREATE
		call #0005	; BDOS
		call CheckDOSError
		ld a,b
		ld (OutFileHandle),a
NoOutputFile:

		call GzipExtract

; Close output file
		ld a,(OutFileHandle)
		ld b,a
		inc a
		jr z,SkipCloseOutput
		ld c,#45	; _CLOSE
		call #0005	; BDOS
		call CheckDOSError
SkipCloseOutput:

; Close input file
		ld a,(InFileHandle)
		ld b,a
		ld c,#45	; _CLOSE
		call #0005	; BDOS
		jp CheckDOSError
		; -- done --


; -- Command line parser --
ParseCLI:	ld de,CliBuffer
		ld hl,TextParameters
		ld bc,255 * 256 + #6B	; _GENV
		call #0005		; BDOS

ParseLoop:	ld a,(de)
		and a
		ret z
		cp "/"
		jr z,ParseOption
		cp " "
		jr nz,ParsePath
ParseNext:	inc de
		jr ParseLoop

ParseOption:	inc de
		ld a,(de)
		and %11011111  ; upper-case
		cp "Q"
		jr z,OptionQuiet
		cp "F"
		jr z,OptionFast
OptionError:	ld hl,TextOptionErr
		jp ExitWithError

OptionQuiet:	ld (Quiet),a		; any non-zero value
		jr OptionNext

OptionFast:	ld (NoCrcCheck),a	; any non-zero value

OptionNext:	inc de
		ld a,(de)
		and a
		ret z
		cp " "
		jr z,ParseNext
		jr OptionError

ParsePath:	ld hl,(InputPath)
		ld a,h
		or l
		jr nz,ParseOPath
		ld (InputPath),de
ParsePath2:	ld c,#5B	; _PARSE
		call #0005	; BDOS
		ld a,(de)
		and a
		ret z
		xor a
		ld (de),a	; make sure path is zero-terminated
		jr ParseNext

ParseOPath:	ld hl,(OutputPath)
		ld a,h
		or l
		ld hl,TextPathErr
		jp nz,ExitWithError
		ld (OutputPath),de
		jr ParsePath2


; -- The actual gunzip code --

GzipExtract:
; Read header
; Header constants
FLAG_HCRC:	equ #02
FLAG_EXTRA:	equ #04
FLAG_NAME:	equ #08
FLAG_COMMENT:	equ #10
FLAG_RESERVED:	equ #20	 ; #E0

		call PrepareRead
; Check two signature bytes
		call ReadByte
		cp 31  ; gzip signature (1)
		ld hl,TextNotGzip
		jp nz,ExitWithError
		call ReadByte
		cp 139  ; gzip signature (1)
		;ld hl,TextNotGzip  ; hl not changed
		jp nz,ExitWithError

; Check compression algorithm
		call ReadByte
		cp 8  ; deflate compression ID (1)
		ld hl,TextNotDeflate
		jp nz,ExitWithError

; Read flags
		call ReadByte
		ld (HeaderFlags),a

; Skip mtime[4], xfl, os
		ld hl,6
		call SkipInputBytes

; Check for unknown flags
		ld a,(HeaderFlags)
		and FLAG_RESERVED
		ld hl,TextUnknownFlag
		jp nz,ExitWithError

; Check and skip extra section
		ld a,(HeaderFlags)
		and FLAG_EXTRA
		jr z,NoSkipExtra
		call ReadByte
		ld l,a
		call ReadByte
		ld h,a
		call SkipInputBytes
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
		call nz,SkipInputBytes

		call FinishRead

; Decompress all blocks in the gz file
InflateLoop:	call PrepareRead
		call Read1Bit
		push af
		call Read2Bits
		push af
		call FinishRead
		pop af
		call InflateBlock
		pop af
		or a
		jr z,InflateLoop

; Finish last (partially filled) OutputBuffer (update count, crc)
		call FinishBlock

; Verify the decompressed data
; Read expected values from file
		call PrepareRead
		call ReadByte
		ld l,a	; bits 7-0
		call ReadByte
		ld h,a	; bits 15-8
		push hl	; expected crc bits 15-0
		call ReadByte
		ld l,a	; bits 23-16
		call ReadByte
		ld h,a	; bits 31-24
		push hl; expected crc bits 31-16

		call ReadByte
		ld l,a	; bits 7-0
		call ReadByte
		ld h,a	; bits 15-8
		push hl	; expected-size bits 15-0
		call ReadByte
		ld l,a	; bits 23-16
		call ReadByte
		ld h,a	; hl = expected-size bits 31-16
		call FinishRead

; Verify size
		ld de,(OutputCount + 2) ; de = actual size bits 31-16
		or a			; hl = expected size bits 31-16
		sbc hl,de
		jr nz,SizeError
		ld de,(OutputCount + 0) ; de = actual size bits 15-0
		pop hl			; hl = expected size bits 15-0
		sbc hl,de
SizeError	ld hl,TextSizeError
		jp nz,ExitWithError

; Verify CRC
		pop hl			; hl = expected crc bits 31-16
		pop de			; de = expected crc bits 15-0
		ld a,(NoCrcCheck)
		or a
		ret nz
		ld bc,(Crc32Value + 2)	; de = actual crc bits 31-16
		scf
		adc hl,bc
		jr nz,CrcError
		ex de,hl
		ld bc,(Crc32Value + 0)	; de = actual crc bits 15-0
		adc hl,bc
CrcError:	ld hl,TextCrcError
		jp nz,ExitWithError
		ret


; Skip zero-terminated string
SkipZString:	call ReadByte
		and a
		jr nz,SkipZString
		ret

; hl = nr of bytes to skip
SkipInputBytes:	call ReadByte
		dec hl
		ld a,h
		or l
		jr nz,SkipInputBytes
		ret


; === Inflate decompression ===
; -- decompress one block --

; a = block type
InflateBlock:	and a
		jr z,Uncompressed
		cp 2
		jr c,FixedComp
		jp z,DynamicComp
		ld hl,TextBlockErr
		jp ExitWithError

; An uncompressed block
Uncompressed:	ld de,(InputBufPos)
		xor a
		ld (InputBits),a	; re-align to byte boundary
		call ReadByte
		ld c,a
		call ReadByte
		ld b,a			; bc = block-length
		call ReadByte
		ld l,a
		call ReadByte
		ld h,a			; hl = complement of block-length
		scf
		adc hl,bc
		ld hl,TextLengthErr
		jp nz,ExitWithError

		ld a,b
		or c
		jr z,UncompEnd	; length = 0
		ld a,c
		dec bc
		inc b
		ld c,b
		ld b,a

		ld hl,(OutputBufPos)
UncompLoop:	call ReadByte
		call WriteByte
		djnz UncompLoop
		dec c
		jr nz,UncompLoop
		ld (OutputBufPos),hl

UncompEnd:	ld (InputBufPos),de
		ret


; A block compressed using the fixed alphabet
FixedComp:	ld bc,FixedLitCount
		ld de,FixedLitLen
		ld hl,LiteralTree
		ld iy,LLSymbols
		call GenerateHuffman
		ld hl,LiteralTreeEnd	;; Sanity check:
		ld de,(HuffOutPtr)	;;  is the 'LiteralTree' buffer
		or a			;;  big enough to hold the
		sbc hl,de		;;  generated code?
		call c,ThrowException	;;

		ld bc,FixedDistCount
		ld de,FixedDistLen
		ld hl,DistanceTree + 1
		ld iy,DistSymbols
		call GenerateHuffman
		ld hl,DistanceTreeEnd	;; Sanity check
		ld de,(HuffOutPtr)	;;
		or a			;;
		sbc hl,de		;;
		call c,ThrowException	;;
		jr DoInflate

; A block compressed using a dynamic alphabet
DynamicComp:	call BuildDynAlpha
DoInflate:	ld a,#D9		; opcode for EXX
		ld (DistanceTree),a
		ld iy,Write_AndNext
		call PrepareRead
		ld hl,(OutputBufPos)
		call LiteralTree
		ld (OutputBufPos),hl
		jp FinishRead


; -- Create dynamic alphabet --

MAX_HEADER_LEN:	equ 19	; maximum number of 'header code lengths'
MAX_LIT_LEN:	equ 286	; maximum number of 'literal/length code lengths'
MAX_DIST_LEN:	equ 30	; maximum number of 'distance code lengths'

BuildDynAlpha:
; Read hlit
		call PrepareRead
		call Read5Bits
		inc a
		cp (MAX_LIT_LEN & 0FFH) + 1
		call nc,ThrowException
		ld (hlit),a

; Read hdist
		call Read5Bits
		inc a
		cp MAX_DIST_LEN + 1
		call nc,ThrowException
		ld (hdist),a

; Read hclen
		call Read4Bits
		add a,4
		cp MAX_HEADER_LEN + 1
		call nc,ThrowException

; Clear header code lengths
		exx
		ld hl,HdrCodeLengths
		ld de,HdrCodeLengths + 1
		ld bc,MAX_HEADER_LEN - 1
		ld (hl),b ; 0
		ldir
		exx

; Read header code lengths
		ld ixl,a	; hclen
		ld hl,HeaderCodeOrder
		ld iy,HdrCodeLengths
DynLoop:	ld a,(hl)
		inc hl
		ld (DynStore + 2),a ; self modifying code!
		call Read3Bits ; changes B
DynStore:	ld (iy + 0),a  ; offset is dynamically changed!
		dec ixl
		jr nz,DynLoop
		push bc
		push de

; Construct header code alphabet
		ld bc,MAX_HEADER_LEN
		ld de,HdrCodeLengths	; de = length of symbols
		ld hl,HeaderTree
		ld iy,HeaderSymbols
		call GenerateHuffman
		ld hl,HeaderTreeEnd	;; Sanity check:
		ld de,(HuffOutPtr)	;;  is the 'HeaderTree' buffer
		or a			;;  big enough to hold the
		sbc hl,de		;;  generated code?
		call c,ThrowException	;;

; Read literal length distance code lengths
		ld bc,(hdist)
		ld ix,(hlit)
		add ix,bc
		inc ixh	; +1 for nested 8-bit loop
		ld hl,LLDCodeLengths
		pop de
		pop bc
		call HeaderTree		; decode the header
		call FinishRead

; Construct literal length alphabet
		ld bc,(hlit) ; bc = number of symbols
		ld de,LLDCodeLengths	; de = length of symbols
		ld hl,LiteralTree
		ld iy,LLSymbols		; iy = literal/length symbol handlers table
		call GenerateHuffman
		ld hl,LiteralTreeEnd	;;
		ld de,(HuffOutPtr)	;;
		or a			;;
		sbc hl,de		;;
		call c,ThrowException	;;

; Construct distance alphabet
		ld bc,(hdist)		; bc = number of symbols
		ld hl,LLDCodeLengths
		ld de,(hlit)
		add hl,de
		ex de,hl		; de = length of symbols
		ld hl,DistanceTree + 1
		ld iy,DistSymbols	; iy = distance symbol handlers table
		call GenerateHuffman
		ld hl,DistanceTreeEnd	;;
		ld de,(HuffOutPtr)	;;
		or a			;;
		sbc hl,de		;;
		call c,ThrowException	;;
		ret


; -- Generate Huffman decoding function --
;
; In:
;  [bc] = number of symbols
;  [de] = table containing length of each symbol
;  [hl] = output-buffer (cannot start below 0x100)
;  [iy] = table containing pointer to leaf-routine for each symbol
; Out:
;  output-buffer filled with decoding function
;  (HuffRoot)    = start of output-buffer (= input parameter)
;  (HuffOutPtr) = end   of output-buffer
; Modifies:
;  - all registers
;  - variables HuffScratch,HuffRoot,HuffOutPtr,LengthsPtr are changed, but can be
;    freely used outside this routine. IOW it's all scratch area.
; Requires:
;  HuffScratch must be 256-byte aligned, must be at least 32 bytes in size

GenerateHuffman:
		ld (HuffRoot),hl
		ld (HuffOutPtr),hl
		ld (LengthsPtr),de
		push bc

; Clear length-counts table
		ld hl,HuffScratch
		ld de,HuffScratch + 1
		ld bc,(2 * 16) - 1
		ld (hl),b		; b = 0
		ldir

		pop bc			; bc = number of symbols
		push bc

; Count occurrences of each symbol-length
		ld de,(LengthsPtr)
		ld h,HuffScratch >> 8	; HuffScratch used as 'int16_t countBuf[16]'
CountLoop:	ld a,(de)		; symbol length
		inc de
		add a,a
		jr z,CountNext
		ld l,a
		inc (hl)		; ++countBuf[length]
		jr nz,CountNext
		inc l
		inc (hl)
CountNext:	dec bc
		ld a,b
		or c
		jr nz,CountLoop

; Calculate next-codes
; Before this loop 'HuffScratch' contains 'uint16_t countBuf[16]'
; After  this loop 'HuffScratch' contains 'uint16_t nextCode[16]'
; IOW 'countBuf' is transformed in-place to 'nextCode'
		ld a,16
		ld d,b			; b = 0
		ld e,b			; de = t = 0
		ld l,b			; hl = HuffScratch
NextCodeLoop:	ld c,(hl)
		ld (hl),e
		inc l
		ld b,(hl)		; bc = countBuf[i]
		ld (hl),d		; nextCode[i] = t
		inc l
		ex de,hl
		add hl,bc
		add hl,hl		; t = (t + countBuf[i]) * 2
		ex de,hl
		dec a
		jr nz,NextCodeLoop

		pop bc			; bc = number of symbols

; Process the next symbol. Add it to the (partially constructed) Huffman tree,
; following exiting nodes and creating new nodes along the way.
SymbolLoop:	push bc			; bc = number of remaining symbols

		ld hl,(LengthsPtr)
		ld c,(hl)		; c = length of symbol
		inc hl
		ld (LengthsPtr),hl	; ++LengthsPtr
		ld a,c
		add a,a
		jp z,NextSymbol
		ld l,a
		ld h,HuffScratch >> 8	; hl = &nextCode[length]

		ld e,(hl)
		inc l
		ld d,(hl)		; de = code = nextCode[length]
		push de
		pop ix			; ix = code
		inc de
		ld (hl),d
		dec l
		ld (hl),e		; ++nextCode[length]

		ld a,16
		sub c			; c = symbol length
		ld b,a			; b is at least 1
ShiftLoop:	add ix,ix		; carry-flag clear
		djnz ShiftLoop

		ld hl,(HuffRoot)	; hl = root node
		ld de,(HuffOutPtr)	; de = location to create new node
		; assert(carry-flag not set)
		sbc hl,de		; does update zero flag
		add hl,de		; does not update zero flag
		jr nz,Follow		; de == hl?
		; de == hl == HuffRoot == HuffOutPtr -> only happens for the very first symbol

CreateLoop:	; invariant: hl -> free space in output buffer
		;            ix -> remaining code bits (MSB aligned)
		;            c  -> number of remaining bits
		;            b  -> 0
; Generate 'ReadBitInlineA'
		ld (hl),0CBH		; SRL C
		inc hl
		ld (hl),39H
		inc hl
		ld (hl),0CCH		; CALL Z,nn
		inc hl
		ld (hl),ReadBitA & 0FFH
		inc hl
		ld (hl),ReadBitA >> 8
		inc hl

; Generate JP NC,0 / JP C,0
		add ix,ix		; shift code -> output bit to carry
		sbc a,a			; a = carry ? 0xff : 0x00
		and 8			; a = carry ? 0x08 : 0x00
		xor 0DAH		; a = carry ? 0xD2 : 0xDA
		ld (hl),a		; carry ? JP_NC : JP_C
		inc hl
		inc hl			; skip low address byte
		ld (hl),b		; b = 0   only mark high address byte
		inc hl

; Next code bit
		dec c			; --length
		jr nz,CreateLoop

; Create leaf node. Inline the leaf routine.
		ld c,(iy + 0)
		ld b,0			; bc = length
		ld e,(iy + 1)
		ld d,(iy + 2)
		ex de,hl		; hl = routine / de = leaf-node
		ldir
		ld (HuffOutPtr),de	; update new output position
		jr NextSymbol

FollowLoop:	add ix,ix		; shift code -> output bit to carry
		sbc a,a			; a = carry ? 0xff : 0x00
		and 8			; a = carry ? 0x08 : 0x00
		xor 0DAH		; a = carry ? 0xD2 : 0xDA
		cp (hl)			; compare with conditional-jump opcode
		inc hl
		inc hl			; skip to high address byte of JP cc,nn
		jr nz,FollowCond

; Follow fall-through path
		inc hl			; fully skip JP cc,nn instruction
		jr Follow

FollowCond:	ld a,(hl)		; high byte of conditional jump
		or a			; address already filled-in?
		jr nz,FollowExisting

; Path does not yet exist
		ld (hl),d		; de = HuffOutPtr
		dec hl
		ld (hl),e		; fill-in address to new node
		ex de,hl
		jr CreateLoop		; create that node

FollowExisting:	dec hl
		ld l,(hl)		; low  address byte
		ld h,a			; high address byte

Follow:		; invariant: hl = current (existing) Huffman node
		;	     de = free buffer space (HuffOutPtr)
		;            ix -> remaining code bits (MSB aligned)
		;            c  -> number of remaining bits
		;            b -> 0
		inc hl
		inc hl
		inc hl
		inc hl
		inc hl			; skip ReadBitInlineA
		dec c
		jr nz,FollowLoop

; Reached an existing leaf node, fill-in jump-address to symbol-routine
		inc hl			; skip conditional jump opcode
		ld a,(iy + 1)
		ld (hl),a
		inc hl
		ld a,(iy + 2)
		ld (hl),a

NextSymbol:	inc iy
		inc iy
		inc iy
		pop bc			; bc = number of remaining symbols
		dec bc
		ld a,b
		or c
		jp nz,SymbolLoop
		ret


; -- Symbol routines used by the 'header decoder' Huffman tree

; Pairs of
;  length  of the routine (1 bytes)
;  pointer to the routine (2 bytes)
HeaderSymbols:	db WriteLen_0_len
		dw WriteLen_0
		db WriteLen_1_len
		dw WriteLen_1
		db WriteLen_2_len
		dw WriteLen_2
		db WriteLen_3_len
		dw WriteLen_3
		db WriteLen_4_len
		dw WriteLen_4
		db WriteLen_5_len
		dw WriteLen_5
		db WriteLen_6_len
		dw WriteLen_6
		db WriteLen_7_len
		dw WriteLen_7
		db WriteLen_8_len
		dw WriteLen_8
		db WriteLen_9_len
		dw WriteLen_9
		db WriteLen_10_len
		dw WriteLen_10
		db WriteLen_11_len
		dw WriteLen_11
		db WriteLen_12_len
		dw WriteLen_12
		db WriteLen_13_len
		dw WriteLen_13
		db WriteLen_14_len
		dw WriteLen_14
		db WriteLen_15_len
		dw WriteLen_15
		db HeaderCopyLen
		dw HeaderCopy
		db HdrZFill3Len
		dw HdrZFill3
		db HdrZFill11Len
		dw HdrZFill11
		db ThrowInlineLen
		dw ThrowInline

; For all of these routines, the calling convention is like this:
; c = bit reader state
; de = InputBufPos
; hl = literal/length/distance code lengths position
; ix = loop counter for nested 8-bit loop

; Header code alphabet symbols 0-15
WriteLen_0:	ld (hl),0
		jp HeaderNext
WriteLen_0_len: equ $-WriteLen_0

WriteLen_1:	ld (hl),1
		jp HeaderNext
WriteLen_1_len: equ $-WriteLen_1

WriteLen_2:	ld (hl),2
		jp HeaderNext
WriteLen_2_len: equ $-WriteLen_2

WriteLen_3:	ld (hl),3
		jp HeaderNext
WriteLen_3_len: equ $-WriteLen_3

WriteLen_4:	ld (hl),4
		jp HeaderNext
WriteLen_4_len: equ $-WriteLen_4

WriteLen_5:	ld (hl),5
		jp HeaderNext
WriteLen_5_len: equ $-WriteLen_5

WriteLen_6:	ld (hl),6
		jp HeaderNext
WriteLen_6_len: equ $-WriteLen_6

WriteLen_7:	ld (hl),7
		jp HeaderNext
WriteLen_7_len: equ $-WriteLen_7

WriteLen_8:	ld (hl),8
		jp HeaderNext
WriteLen_8_len: equ $-WriteLen_8

WriteLen_9:	ld (hl),9
		jp HeaderNext
WriteLen_9_len: equ $-WriteLen_9

WriteLen_10:	ld (hl),10
		jp HeaderNext
WriteLen_10_len: equ $-WriteLen_10

WriteLen_11:	ld (hl),11
		jp HeaderNext
WriteLen_11_len: equ $-WriteLen_11

WriteLen_12:	ld (hl),12
		jp HeaderNext
WriteLen_12_len: equ $-WriteLen_12

WriteLen_13:	ld (hl),13
		jp HeaderNext
WriteLen_13_len: equ $-WriteLen_13

WriteLen_14:	ld (hl),14
		jp HeaderNext
WriteLen_14_len: equ $-WriteLen_14

WriteLen_15:	ld (hl),15
		jp HeaderNext
WriteLen_15_len: equ $-WriteLen_15

; Header code alphabet symbol 16
HeaderCopy:	call Read2Bits
		add a,3
		ld b,a
		dec hl
		ld a,(hl)
		inc hl
		jp HeaderFill
HeaderCopyLen:	equ $ - HeaderCopy

; Header code alphabet symbol 17
HdrZFill3:	call Read3Bits
		add a,3
		ld b,a
		xor a
		jp HeaderFill
HdrZFill3Len:	equ $-HdrZFill3

; Header code alphabet symbol 18
HdrZFill11:	call Read7Bits
		add a,11
		ld b,a
		xor a
		jp HeaderFill
HdrZFill11Len:	equ $ - HdrZFill11


HeaderNext:	inc hl
		dec ixl
		jp nz,HeaderTree
		dec ixh
		jp nz,HeaderTree
		ret

; a = fill value
; b = repeat count
FillLoop:	dec b
		jp z,HeaderTree
HeaderFill:	ld (hl),a
		inc hl
		dec ixl
		jp nz,FillLoop
		dec ixh
		jr nz,FillLoop
		ret

; Inline-able version of 'ThrowException'
ThrowInline:	jp ThrowException
ThrowInlineLen:	equ $ - ThrowInline


; -- Symbol routines used by the 'literal + copy-length' Huffman tree

LLSymbols:	db WriteLitLen00	; 0
		dw WriteLit00
		db WriteLitLen
		dw WriteLit01
		db WriteLitLen
		dw WriteLit02
		db WriteLitLen
		dw WriteLit03
		db WriteLitLen
		dw WriteLit04
		db WriteLitLen
		dw WriteLit05
		db WriteLitLen
		dw WriteLit06
		db WriteLitLen
		dw WriteLit07
		db WriteLitLen
		dw WriteLit08
		db WriteLitLen
		dw WriteLit09
		db WriteLitLen
		dw WriteLit0A
		db WriteLitLen
		dw WriteLit0B
		db WriteLitLen
		dw WriteLit0C
		db WriteLitLen
		dw WriteLit0D
		db WriteLitLen
		dw WriteLit0E
		db WriteLitLen
		dw WriteLit0F
		db WriteLitLen
		dw WriteLit10
		db WriteLitLen
		dw WriteLit11
		db WriteLitLen
		dw WriteLit12
		db WriteLitLen
		dw WriteLit13
		db WriteLitLen
		dw WriteLit14
		db WriteLitLen
		dw WriteLit15
		db WriteLitLen
		dw WriteLit16
		db WriteLitLen
		dw WriteLit17
		db WriteLitLen
		dw WriteLit18
		db WriteLitLen
		dw WriteLit19
		db WriteLitLen
		dw WriteLit1A
		db WriteLitLen
		dw WriteLit1B
		db WriteLitLen
		dw WriteLit1C
		db WriteLitLen
		dw WriteLit1D
		db WriteLitLen
		dw WriteLit1E
		db WriteLitLen
		dw WriteLit1F
		db WriteLitLen
		dw WriteLit20
		db WriteLitLen
		dw WriteLit21
		db WriteLitLen
		dw WriteLit22
		db WriteLitLen
		dw WriteLit23
		db WriteLitLen
		dw WriteLit24
		db WriteLitLen
		dw WriteLit25
		db WriteLitLen
		dw WriteLit26
		db WriteLitLen
		dw WriteLit27
		db WriteLitLen
		dw WriteLit28
		db WriteLitLen
		dw WriteLit29
		db WriteLitLen
		dw WriteLit2A
		db WriteLitLen
		dw WriteLit2B
		db WriteLitLen
		dw WriteLit2C
		db WriteLitLen
		dw WriteLit2D
		db WriteLitLen
		dw WriteLit2E
		db WriteLitLen
		dw WriteLit2F
		db WriteLitLen
		dw WriteLit30
		db WriteLitLen
		dw WriteLit31
		db WriteLitLen
		dw WriteLit32
		db WriteLitLen
		dw WriteLit33
		db WriteLitLen
		dw WriteLit34
		db WriteLitLen
		dw WriteLit35
		db WriteLitLen
		dw WriteLit36
		db WriteLitLen
		dw WriteLit37
		db WriteLitLen
		dw WriteLit38
		db WriteLitLen
		dw WriteLit39
		db WriteLitLen
		dw WriteLit3A
		db WriteLitLen
		dw WriteLit3B
		db WriteLitLen
		dw WriteLit3C
		db WriteLitLen
		dw WriteLit3D
		db WriteLitLen
		dw WriteLit3E
		db WriteLitLen
		dw WriteLit3F
		db WriteLitLen
		dw WriteLit40
		db WriteLitLen
		dw WriteLit41
		db WriteLitLen
		dw WriteLit42
		db WriteLitLen
		dw WriteLit43
		db WriteLitLen
		dw WriteLit44
		db WriteLitLen
		dw WriteLit45
		db WriteLitLen
		dw WriteLit46
		db WriteLitLen
		dw WriteLit47
		db WriteLitLen
		dw WriteLit48
		db WriteLitLen
		dw WriteLit49
		db WriteLitLen
		dw WriteLit4A
		db WriteLitLen
		dw WriteLit4B
		db WriteLitLen
		dw WriteLit4C
		db WriteLitLen
		dw WriteLit4D
		db WriteLitLen
		dw WriteLit4E
		db WriteLitLen
		dw WriteLit4F
		db WriteLitLen
		dw WriteLit50
		db WriteLitLen
		dw WriteLit51
		db WriteLitLen
		dw WriteLit52
		db WriteLitLen
		dw WriteLit53
		db WriteLitLen
		dw WriteLit54
		db WriteLitLen
		dw WriteLit55
		db WriteLitLen
		dw WriteLit56
		db WriteLitLen
		dw WriteLit57
		db WriteLitLen
		dw WriteLit58
		db WriteLitLen
		dw WriteLit59
		db WriteLitLen
		dw WriteLit5A
		db WriteLitLen
		dw WriteLit5B
		db WriteLitLen
		dw WriteLit5C
		db WriteLitLen
		dw WriteLit5D
		db WriteLitLen
		dw WriteLit5E
		db WriteLitLen
		dw WriteLit5F
		db WriteLitLen
		dw WriteLit60
		db WriteLitLen
		dw WriteLit61
		db WriteLitLen
		dw WriteLit62
		db WriteLitLen
		dw WriteLit63
		db WriteLitLen
		dw WriteLit64
		db WriteLitLen
		dw WriteLit65
		db WriteLitLen
		dw WriteLit66
		db WriteLitLen
		dw WriteLit67
		db WriteLitLen
		dw WriteLit68
		db WriteLitLen
		dw WriteLit69
		db WriteLitLen
		dw WriteLit6A
		db WriteLitLen
		dw WriteLit6B
		db WriteLitLen
		dw WriteLit6C
		db WriteLitLen
		dw WriteLit6D
		db WriteLitLen
		dw WriteLit6E
		db WriteLitLen
		dw WriteLit6F
		db WriteLitLen
		dw WriteLit70
		db WriteLitLen
		dw WriteLit71
		db WriteLitLen
		dw WriteLit72
		db WriteLitLen
		dw WriteLit73
		db WriteLitLen
		dw WriteLit74
		db WriteLitLen
		dw WriteLit75
		db WriteLitLen
		dw WriteLit76
		db WriteLitLen
		dw WriteLit77
		db WriteLitLen
		dw WriteLit78
		db WriteLitLen
		dw WriteLit79
		db WriteLitLen
		dw WriteLit7A
		db WriteLitLen
		dw WriteLit7B
		db WriteLitLen
		dw WriteLit7C
		db WriteLitLen
		dw WriteLit7D
		db WriteLitLen
		dw WriteLit7E
		db WriteLitLen
		dw WriteLit7F
		db WriteLitLen
		dw WriteLit80
		db WriteLitLen
		dw WriteLit81
		db WriteLitLen
		dw WriteLit82
		db WriteLitLen
		dw WriteLit83
		db WriteLitLen
		dw WriteLit84
		db WriteLitLen
		dw WriteLit85
		db WriteLitLen
		dw WriteLit86
		db WriteLitLen
		dw WriteLit87
		db WriteLitLen
		dw WriteLit88
		db WriteLitLen
		dw WriteLit89
		db WriteLitLen
		dw WriteLit8A
		db WriteLitLen
		dw WriteLit8B
		db WriteLitLen
		dw WriteLit8C
		db WriteLitLen
		dw WriteLit8D
		db WriteLitLen
		dw WriteLit8E
		db WriteLitLen
		dw WriteLit8F
		db WriteLitLen
		dw WriteLit90
		db WriteLitLen
		dw WriteLit91
		db WriteLitLen
		dw WriteLit92
		db WriteLitLen
		dw WriteLit93
		db WriteLitLen
		dw WriteLit94
		db WriteLitLen
		dw WriteLit95
		db WriteLitLen
		dw WriteLit96
		db WriteLitLen
		dw WriteLit97
		db WriteLitLen
		dw WriteLit98
		db WriteLitLen
		dw WriteLit99
		db WriteLitLen
		dw WriteLit9A
		db WriteLitLen
		dw WriteLit9B
		db WriteLitLen
		dw WriteLit9C
		db WriteLitLen
		dw WriteLit9D
		db WriteLitLen
		dw WriteLit9E
		db WriteLitLen
		dw WriteLit9F
		db WriteLitLen
		dw WriteLitA0
		db WriteLitLen
		dw WriteLitA1
		db WriteLitLen
		dw WriteLitA2
		db WriteLitLen
		dw WriteLitA3
		db WriteLitLen
		dw WriteLitA4
		db WriteLitLen
		dw WriteLitA5
		db WriteLitLen
		dw WriteLitA6
		db WriteLitLen
		dw WriteLitA7
		db WriteLitLen
		dw WriteLitA8
		db WriteLitLen
		dw WriteLitA9
		db WriteLitLen
		dw WriteLitAA
		db WriteLitLen
		dw WriteLitAB
		db WriteLitLen
		dw WriteLitAC
		db WriteLitLen
		dw WriteLitAD
		db WriteLitLen
		dw WriteLitAE
		db WriteLitLen
		dw WriteLitAF
		db WriteLitLen
		dw WriteLitB0
		db WriteLitLen
		dw WriteLitB1
		db WriteLitLen
		dw WriteLitB2
		db WriteLitLen
		dw WriteLitB3
		db WriteLitLen
		dw WriteLitB4
		db WriteLitLen
		dw WriteLitB5
		db WriteLitLen
		dw WriteLitB6
		db WriteLitLen
		dw WriteLitB7
		db WriteLitLen
		dw WriteLitB8
		db WriteLitLen
		dw WriteLitB9
		db WriteLitLen
		dw WriteLitBA
		db WriteLitLen
		dw WriteLitBB
		db WriteLitLen
		dw WriteLitBC
		db WriteLitLen
		dw WriteLitBD
		db WriteLitLen
		dw WriteLitBE
		db WriteLitLen
		dw WriteLitBF
		db WriteLitLen
		dw WriteLitC0
		db WriteLitLen
		dw WriteLitC1
		db WriteLitLen
		dw WriteLitC2
		db WriteLitLen
		dw WriteLitC3
		db WriteLitLen
		dw WriteLitC4
		db WriteLitLen
		dw WriteLitC5
		db WriteLitLen
		dw WriteLitC6
		db WriteLitLen
		dw WriteLitC7
		db WriteLitLen
		dw WriteLitC8
		db WriteLitLen
		dw WriteLitC9
		db WriteLitLen
		dw WriteLitCA
		db WriteLitLen
		dw WriteLitCB
		db WriteLitLen
		dw WriteLitCC
		db WriteLitLen
		dw WriteLitCD
		db WriteLitLen
		dw WriteLitCE
		db WriteLitLen
		dw WriteLitCF
		db WriteLitLen
		dw WriteLitD0
		db WriteLitLen
		dw WriteLitD1
		db WriteLitLen
		dw WriteLitD2
		db WriteLitLen
		dw WriteLitD3
		db WriteLitLen
		dw WriteLitD4
		db WriteLitLen
		dw WriteLitD5
		db WriteLitLen
		dw WriteLitD6
		db WriteLitLen
		dw WriteLitD7
		db WriteLitLen
		dw WriteLitD8
		db WriteLitLen
		dw WriteLitD9
		db WriteLitLen
		dw WriteLitDA
		db WriteLitLen
		dw WriteLitDB
		db WriteLitLen
		dw WriteLitDC
		db WriteLitLen
		dw WriteLitDD
		db WriteLitLen
		dw WriteLitDE
		db WriteLitLen
		dw WriteLitDF
		db WriteLitLen
		dw WriteLitE0
		db WriteLitLen
		dw WriteLitE1
		db WriteLitLen
		dw WriteLitE2
		db WriteLitLen
		dw WriteLitE3
		db WriteLitLen
		dw WriteLitE4
		db WriteLitLen
		dw WriteLitE5
		db WriteLitLen
		dw WriteLitE6
		db WriteLitLen
		dw WriteLitE7
		db WriteLitLen
		dw WriteLitE8
		db WriteLitLen
		dw WriteLitE9
		db WriteLitLen
		dw WriteLitEA
		db WriteLitLen
		dw WriteLitEB
		db WriteLitLen
		dw WriteLitEC
		db WriteLitLen
		dw WriteLitED
		db WriteLitLen
		dw WriteLitEE
		db WriteLitLen
		dw WriteLitEF
		db WriteLitLen
		dw WriteLitF0
		db WriteLitLen
		dw WriteLitF1
		db WriteLitLen
		dw WriteLitF2
		db WriteLitLen
		dw WriteLitF3
		db WriteLitLen
		dw WriteLitF4
		db WriteLitLen
		dw WriteLitF5
		db WriteLitLen
		dw WriteLitF6
		db WriteLitLen
		dw WriteLitF7
		db WriteLitLen
		dw WriteLitF8
		db WriteLitLen
		dw WriteLitF9
		db WriteLitLen
		dw WriteLitFA
		db WriteLitLen
		dw WriteLitFB
		db WriteLitLen
		dw WriteLitFC
		db WriteLitLen
		dw WriteLitFD
		db WriteLitLen
		dw WriteLitFE
		db WriteLitLen
		dw WriteLitFF
		db EndBlockLen	; 256
		dw EndBlock
		db CopyLen0Len	; 257
		dw CopyLen0
		db CopyLen1Len
		dw CopyLen1
		db CopyLen2Len
		dw CopyLen2
		db CopyLen3Len
		dw CopyLen3
		db CopyLen4Len
		dw CopyLen4
		db CopyLen5Len
		dw CopyLen5
		db CopyLen6Len
		dw CopyLen6
		db CopyLen7Len
		dw CopyLen7
		db CopyLen8Len
		dw CopyLen8
		db CopyLen9Len
		dw CopyLen9
		db CopyLen10Len
		dw CopyLen10
		db CopyLen11Len
		dw CopyLen11
		db CopyLen12Len
		dw CopyLen12
		db CopyLen13Len
		dw CopyLen13
		db CopyLen14Len
		dw CopyLen14
		db CopyLen15Len
		dw CopyLen15
		db CopyLen16Len
		dw CopyLen16
		db CopyLen17Len
		dw CopyLen17
		db CopyLen18Len
		dw CopyLen18
		db CopyLen19Len
		dw CopyLen19
		db CopyLen20Len
		dw CopyLen20
		db CopyLen21Len
		dw CopyLen21
		db CopyLen22Len
		dw CopyLen22
		db CopyLen23Len
		dw CopyLen23
		db CopyLen24Len
		dw CopyLen24
		db CopyLen25Len
		dw CopyLen25
		db CopyLen26Len
		dw CopyLen26
		db CopyLen27Len
		dw CopyLen27
		db CopyLen28Len
		dw CopyLen28
		db ThrowInlineLen	; 286
		dw ThrowInline
		db ThrowInlineLen	; 287
		dw ThrowInline

; For all of these routines, the calling convention is like this:
; c = bit reader state
; de = InputBufPos
; hl = OutputBufPos
; iy = Write_AndNext

; Literal/length alphabet symbols 0-255
WriteLit00:	xor a		; special case
		jp iy		; Write_AndNext
WriteLit01:	ld a,#01
		jp iy
WriteLit02:	ld a,#02
		jp iy
WriteLit03:	ld a,#03
		jp iy
WriteLit04:	ld a,#04
		jp iy
WriteLit05:	ld a,#05
		jp iy
WriteLit06:	ld a,#06
		jp iy
WriteLit07:	ld a,#07
		jp iy
WriteLit08:	ld a,#08
		jp iy
WriteLit09:	ld a,#09
		jp iy
WriteLit0A:	ld a,#0A
		jp iy
WriteLit0B:	ld a,#0B
		jp iy
WriteLit0C:	ld a,#0C
		jp iy
WriteLit0D:	ld a,#0D
		jp iy
WriteLit0E:	ld a,#0E
		jp iy
WriteLit0F:	ld a,#0F
		jp iy
WriteLit10:	ld a,#10
		jp iy
WriteLit11:	ld a,#11
		jp iy
WriteLit12:	ld a,#12
		jp iy
WriteLit13:	ld a,#13
		jp iy
WriteLit14:	ld a,#14
		jp iy
WriteLit15:	ld a,#15
		jp iy
WriteLit16:	ld a,#16
		jp iy
WriteLit17:	ld a,#17
		jp iy
WriteLit18:	ld a,#18
		jp iy
WriteLit19:	ld a,#19
		jp iy
WriteLit1A:	ld a,#1A
		jp iy
WriteLit1B:	ld a,#1B
		jp iy
WriteLit1C:	ld a,#1C
		jp iy
WriteLit1D:	ld a,#1D
		jp iy
WriteLit1E:	ld a,#1E
		jp iy
WriteLit1F:	ld a,#1F
		jp iy
WriteLit20:	ld a,#20
		jp iy
WriteLit21:	ld a,#21
		jp iy
WriteLit22:	ld a,#22
		jp iy
WriteLit23:	ld a,#23
		jp iy
WriteLit24:	ld a,#24
		jp iy
WriteLit25:	ld a,#25
		jp iy
WriteLit26:	ld a,#26
		jp iy
WriteLit27:	ld a,#27
		jp iy
WriteLit28:	ld a,#28
		jp iy
WriteLit29:	ld a,#29
		jp iy
WriteLit2A:	ld a,#2A
		jp iy
WriteLit2B:	ld a,#2B
		jp iy
WriteLit2C:	ld a,#2C
		jp iy
WriteLit2D:	ld a,#2D
		jp iy
WriteLit2E:	ld a,#2E
		jp iy
WriteLit2F:	ld a,#2F
		jp iy
WriteLit30:	ld a,#30
		jp iy
WriteLit31:	ld a,#31
		jp iy
WriteLit32:	ld a,#32
		jp iy
WriteLit33:	ld a,#33
		jp iy
WriteLit34:	ld a,#34
		jp iy
WriteLit35:	ld a,#35
		jp iy
WriteLit36:	ld a,#36
		jp iy
WriteLit37:	ld a,#37
		jp iy
WriteLit38:	ld a,#38
		jp iy
WriteLit39:	ld a,#39
		jp iy
WriteLit3A:	ld a,#3A
		jp iy
WriteLit3B:	ld a,#3B
		jp iy
WriteLit3C:	ld a,#3C
		jp iy
WriteLit3D:	ld a,#3D
		jp iy
WriteLit3E:	ld a,#3E
		jp iy
WriteLit3F:	ld a,#3F
		jp iy
WriteLit40:	ld a,#40
		jp iy
WriteLit41:	ld a,#41
		jp iy
WriteLit42:	ld a,#42
		jp iy
WriteLit43:	ld a,#43
		jp iy
WriteLit44:	ld a,#44
		jp iy
WriteLit45:	ld a,#45
		jp iy
WriteLit46:	ld a,#46
		jp iy
WriteLit47:	ld a,#47
		jp iy
WriteLit48:	ld a,#48
		jp iy
WriteLit49:	ld a,#49
		jp iy
WriteLit4A:	ld a,#4A
		jp iy
WriteLit4B:	ld a,#4B
		jp iy
WriteLit4C:	ld a,#4C
		jp iy
WriteLit4D:	ld a,#4D
		jp iy
WriteLit4E:	ld a,#4E
		jp iy
WriteLit4F:	ld a,#4F
		jp iy
WriteLit50:	ld a,#50
		jp iy
WriteLit51:	ld a,#51
		jp iy
WriteLit52:	ld a,#52
		jp iy
WriteLit53:	ld a,#53
		jp iy
WriteLit54:	ld a,#54
		jp iy
WriteLit55:	ld a,#55
		jp iy
WriteLit56:	ld a,#56
		jp iy
WriteLit57:	ld a,#57
		jp iy
WriteLit58:	ld a,#58
		jp iy
WriteLit59:	ld a,#59
		jp iy
WriteLit5A:	ld a,#5A
		jp iy
WriteLit5B:	ld a,#5B
		jp iy
WriteLit5C:	ld a,#5C
		jp iy
WriteLit5D:	ld a,#5D
		jp iy
WriteLit5E:	ld a,#5E
		jp iy
WriteLit5F:	ld a,#5F
		jp iy
WriteLit60:	ld a,#60
		jp iy
WriteLit61:	ld a,#61
		jp iy
WriteLit62:	ld a,#62
		jp iy
WriteLit63:	ld a,#63
		jp iy
WriteLit64:	ld a,#64
		jp iy
WriteLit65:	ld a,#65
		jp iy
WriteLit66:	ld a,#66
		jp iy
WriteLit67:	ld a,#67
		jp iy
WriteLit68:	ld a,#68
		jp iy
WriteLit69:	ld a,#69
		jp iy
WriteLit6A:	ld a,#6A
		jp iy
WriteLit6B:	ld a,#6B
		jp iy
WriteLit6C:	ld a,#6C
		jp iy
WriteLit6D:	ld a,#6D
		jp iy
WriteLit6E:	ld a,#6E
		jp iy
WriteLit6F:	ld a,#6F
		jp iy
WriteLit70:	ld a,#70
		jp iy
WriteLit71:	ld a,#71
		jp iy
WriteLit72:	ld a,#72
		jp iy
WriteLit73:	ld a,#73
		jp iy
WriteLit74:	ld a,#74
		jp iy
WriteLit75:	ld a,#75
		jp iy
WriteLit76:	ld a,#76
		jp iy
WriteLit77:	ld a,#77
		jp iy
WriteLit78:	ld a,#78
		jp iy
WriteLit79:	ld a,#79
		jp iy
WriteLit7A:	ld a,#7A
		jp iy
WriteLit7B:	ld a,#7B
		jp iy
WriteLit7C:	ld a,#7C
		jp iy
WriteLit7D:	ld a,#7D
		jp iy
WriteLit7E:	ld a,#7E
		jp iy
WriteLit7F:	ld a,#7F
		jp iy
WriteLit80:	ld a,#80
		jp iy
WriteLit81:	ld a,#81
		jp iy
WriteLit82:	ld a,#82
		jp iy
WriteLit83:	ld a,#83
		jp iy
WriteLit84:	ld a,#84
		jp iy
WriteLit85:	ld a,#85
		jp iy
WriteLit86:	ld a,#86
		jp iy
WriteLit87:	ld a,#87
		jp iy
WriteLit88:	ld a,#88
		jp iy
WriteLit89:	ld a,#89
		jp iy
WriteLit8A:	ld a,#8A
		jp iy
WriteLit8B:	ld a,#8B
		jp iy
WriteLit8C:	ld a,#8C
		jp iy
WriteLit8D:	ld a,#8D
		jp iy
WriteLit8E:	ld a,#8E
		jp iy
WriteLit8F:	ld a,#8F
		jp iy
WriteLit90:	ld a,#90
		jp iy
WriteLit91:	ld a,#91
		jp iy
WriteLit92:	ld a,#92
		jp iy
WriteLit93:	ld a,#93
		jp iy
WriteLit94:	ld a,#94
		jp iy
WriteLit95:	ld a,#95
		jp iy
WriteLit96:	ld a,#96
		jp iy
WriteLit97:	ld a,#97
		jp iy
WriteLit98:	ld a,#98
		jp iy
WriteLit99:	ld a,#99
		jp iy
WriteLit9A:	ld a,#9A
		jp iy
WriteLit9B:	ld a,#9B
		jp iy
WriteLit9C:	ld a,#9C
		jp iy
WriteLit9D:	ld a,#9D
		jp iy
WriteLit9E:	ld a,#9E
		jp iy
WriteLit9F:	ld a,#9F
		jp iy
WriteLitA0:	ld a,#A0
		jp iy
WriteLitA1:	ld a,#A1
		jp iy
WriteLitA2:	ld a,#A2
		jp iy
WriteLitA3:	ld a,#A3
		jp iy
WriteLitA4:	ld a,#A4
		jp iy
WriteLitA5:	ld a,#A5
		jp iy
WriteLitA6:	ld a,#A6
		jp iy
WriteLitA7:	ld a,#A7
		jp iy
WriteLitA8:	ld a,#A8
		jp iy
WriteLitA9:	ld a,#A9
		jp iy
WriteLitAA:	ld a,#AA
		jp iy
WriteLitAB:	ld a,#AB
		jp iy
WriteLitAC:	ld a,#AC
		jp iy
WriteLitAD:	ld a,#AD
		jp iy
WriteLitAE:	ld a,#AE
		jp iy
WriteLitAF:	ld a,#AF
		jp iy
WriteLitB0:	ld a,#B0
		jp iy
WriteLitB1:	ld a,#B1
		jp iy
WriteLitB2:	ld a,#B2
		jp iy
WriteLitB3:	ld a,#B3
		jp iy
WriteLitB4:	ld a,#B4
		jp iy
WriteLitB5:	ld a,#B5
		jp iy
WriteLitB6:	ld a,#B6
		jp iy
WriteLitB7:	ld a,#B7
		jp iy
WriteLitB8:	ld a,#B8
		jp iy
WriteLitB9:	ld a,#B9
		jp iy
WriteLitBA:	ld a,#BA
		jp iy
WriteLitBB:	ld a,#BB
		jp iy
WriteLitBC:	ld a,#BC
		jp iy
WriteLitBD:	ld a,#BD
		jp iy
WriteLitBE:	ld a,#BE
		jp iy
WriteLitBF:	ld a,#BF
		jp iy
WriteLitC0:	ld a,#C0
		jp iy
WriteLitC1:	ld a,#C1
		jp iy
WriteLitC2:	ld a,#C2
		jp iy
WriteLitC3:	ld a,#C3
		jp iy
WriteLitC4:	ld a,#C4
		jp iy
WriteLitC5:	ld a,#C5
		jp iy
WriteLitC6:	ld a,#C6
		jp iy
WriteLitC7:	ld a,#C7
		jp iy
WriteLitC8:	ld a,#C8
		jp iy
WriteLitC9:	ld a,#C9
		jp iy
WriteLitCA:	ld a,#CA
		jp iy
WriteLitCB:	ld a,#CB
		jp iy
WriteLitCC:	ld a,#CC
		jp iy
WriteLitCD:	ld a,#CD
		jp iy
WriteLitCE:	ld a,#CE
		jp iy
WriteLitCF:	ld a,#CF
		jp iy
WriteLitD0:	ld a,#D0
		jp iy
WriteLitD1:	ld a,#D1
		jp iy
WriteLitD2:	ld a,#D2
		jp iy
WriteLitD3:	ld a,#D3
		jp iy
WriteLitD4:	ld a,#D4
		jp iy
WriteLitD5:	ld a,#D5
		jp iy
WriteLitD6:	ld a,#D6
		jp iy
WriteLitD7:	ld a,#D7
		jp iy
WriteLitD8:	ld a,#D8
		jp iy
WriteLitD9:	ld a,#D9
		jp iy
WriteLitDA:	ld a,#DA
		jp iy
WriteLitDB:	ld a,#DB
		jp iy
WriteLitDC:	ld a,#DC
		jp iy
WriteLitDD:	ld a,#DD
		jp iy
WriteLitDE:	ld a,#DE
		jp iy
WriteLitDF:	ld a,#DF
		jp iy
WriteLitE0:	ld a,#E0
		jp iy
WriteLitE1:	ld a,#E1
		jp iy
WriteLitE2:	ld a,#E2
		jp iy
WriteLitE3:	ld a,#E3
		jp iy
WriteLitE4:	ld a,#E4
		jp iy
WriteLitE5:	ld a,#E5
		jp iy
WriteLitE6:	ld a,#E6
		jp iy
WriteLitE7:	ld a,#E7
		jp iy
WriteLitE8:	ld a,#E8
		jp iy
WriteLitE9:	ld a,#E9
		jp iy
WriteLitEA:	ld a,#EA
		jp iy
WriteLitEB:	ld a,#EB
		jp iy
WriteLitEC:	ld a,#EC
		jp iy
WriteLitED:	ld a,#ED
		jp iy
WriteLitEE:	ld a,#EE
		jp iy
WriteLitEF:	ld a,#EF
		jp iy
WriteLitF0:	ld a,#F0
		jp iy
WriteLitF1:	ld a,#F1
		jp iy
WriteLitF2:	ld a,#F2
		jp iy
WriteLitF3:	ld a,#F3
		jp iy
WriteLitF4:	ld a,#F4
		jp iy
WriteLitF5:	ld a,#F5
		jp iy
WriteLitF6:	ld a,#F6
		jp iy
WriteLitF7:	ld a,#F7
		jp iy
WriteLitF8:	ld a,#F8
		jp iy
WriteLitF9:	ld a,#F9
		jp iy
WriteLitFA:	ld a,#FA
		jp iy
WriteLitFB:	ld a,#FB
		jp iy
WriteLitFC:	ld a,#FC
		jp iy
WriteLitFD:	ld a,#FD
		jp iy
WriteLitFE:	ld a,#FE
		jp iy
WriteLitFF:	ld a,#FF
		jp iy

WriteLitLen00:	equ WriteLit01 - WriteLit00	; special case for 00
WriteLitLen:	equ WriteLit02 - WriteLit01	; all other cases


; Literal/length alphabet symbol 256
EndBlock:	ret	; done inflating this block
EndBlockLen:	equ $ - EndBlock


; Literal/length alphabet symbols 257-285
CopyLen0:	exx
		ld bc,3
		jp DistanceTree
CopyLen0Len:	equ $ - CopyLen0

CopyLen1:	exx
		ld bc,4
		jp DistanceTree
CopyLen1Len:	equ $ - CopyLen1

CopyLen2:	exx
		ld bc,5
		jp DistanceTree
CopyLen2Len:	equ $ - CopyLen2

CopyLen3:	exx
		ld bc,6
		jp DistanceTree
CopyLen3Len:	equ $ - CopyLen3

CopyLen4:	exx
		ld bc,7
		jp DistanceTree
CopyLen4Len:	equ $ - CopyLen4

CopyLen5:	exx
		ld bc,8
		jp DistanceTree
CopyLen5Len:	equ $ - CopyLen5

CopyLen6:	exx
		ld bc,9
		jp DistanceTree
CopyLen6Len:	equ $ - CopyLen6

CopyLen7:	exx
		ld bc,10
		jp DistanceTree
CopyLen7Len:	equ $ - CopyLen7

CopyLen8:	call Read1Bit
		add a,11
		jp CopySetLength
CopyLen8Len:	equ $ - CopyLen8

CopyLen9:	call Read1Bit
		add a,13
		jp CopySetLength
CopyLen9Len:	equ $ - CopyLen9

CopyLen10:	call Read1Bit
		add a,15
		jp CopySetLength
CopyLen10Len:	equ $ - CopyLen10

CopyLen11:	call Read1Bit
		add a,17
		jp CopySetLength
CopyLen11Len:	equ $ - CopyLen11

CopyLen12:	call Read2Bits
		add a,19
		jp CopySetLength
CopyLen12Len:	equ $ - CopyLen12

CopyLen13:	call Read2Bits
		add a,23
		jp CopySetLength
CopyLen13Len:	equ $ - CopyLen13

CopyLen14:	call Read2Bits
		add a,27
		jp CopySetLength
CopyLen14Len:	equ $ - CopyLen14

CopyLen15:	call Read2Bits
		add a,31
		jp CopySetLength
CopyLen15Len:	equ $ - CopyLen15

CopyLen16:	call Read3Bits
		add a,35
		jp CopySetLength
CopyLen16Len:	equ $ - CopyLen16

CopyLen17:	call Read3Bits
		add a,43
		jp CopySetLength
CopyLen17Len:	equ $ - CopyLen17

CopyLen18:	call Read3Bits
		add a,51
		jp CopySetLength
CopyLen18Len:	equ $ - CopyLen18

CopyLen19:	call Read3Bits
		add a,59
		jp CopySetLength
CopyLen19Len:	equ $ - CopyLen19

CopyLen20:	call Read4Bits
		add a,67
		jp CopySetLength
CopyLen20Len:	equ $ - CopyLen20

CopyLen21:	call Read4Bits
		add a,83
		jp CopySetLength
CopyLen21Len:	equ $ - CopyLen21

CopyLen22:	call Read4Bits
		add a,99
		jp CopySetLength
CopyLen22Len:	equ $ - CopyLen22

CopyLen23:	call Read4Bits
		add a,115
		jp CopySetLength
CopyLen23Len:	equ $ - CopyLen23

CopyLen24:	call Read5Bits
		add a,131
		jp CopySetLength
CopyLen24Len:	equ $ - CopyLen24

CopyLen25:	call Read5Bits
		add a,163
		jp CopySetLength
CopyLen25Len:	equ $ - CopyLen25

CopyLen26:	call Read5Bits
		add a,195
		jp CopySetLength
CopyLen26Len:	equ $ - CopyLen26

CopyLen27:	call Read5Bits
		add a,227
		exx
		ld c,a
		jp nc,CopySetLength0
		ld b,1
		jp DistanceTree
CopyLen27Len:	equ $ - CopyLen27

CopyLen28:	exx
		ld bc,258
		jp DistanceTree
CopyLen28Len:	equ $ - CopyLen28

; a = length
CopySetLength:	exx
		ld c,a
CopySetLength0:	ld b,0
		jp DistanceTree


; -- Symbol routines used by the 'distance' Huffman tree

DistSymbols:	db CopyDist0Len
		dw CopyDist0
		db CopyDist1Len
		dw CopyDist1
		db CopyDist2Len
		dw CopyDist2
		db CopyDist3Len
		dw CopyDist3
		db CopyDist4Len
		dw CopyDist4
		db CopyDist5Len
		dw CopyDist5
		db CopyDist6Len
		dw CopyDist6
		db CopyDist7Len
		dw CopyDist7
		db CopyDist8Len
		dw CopyDist8
		db CopyDist9Len
		dw CopyDist9
		db CopyDist10Len
		dw CopyDist10
		db CopyDist11Len
		dw CopyDist11
		db CopyDist12Len
		dw CopyDist12
		db CopyDist13Len
		dw CopyDist13
		db CopyDist14Len
		dw CopyDist14
		db CopyDist15Len
		dw CopyDist15
		db CopyDist16Len
		dw CopyDist16
		db CopyDist17Len
		dw CopyDist17
		db CopyDist18Len
		dw CopyDist18
		db CopyDist19Len
		dw CopyDist19
		db CopyDist20Len
		dw CopyDist20
		db CopyDist21Len
		dw CopyDist21
		db CopyDist22Len
		dw CopyDist22
		db CopyDist23Len
		dw CopyDist23
		db CopyDist24Len
		dw CopyDist24
		db CopyDist25Len
		dw CopyDist25
		db CopyDist26Len
		dw CopyDist26
		db CopyDist27Len
		dw CopyDist27
		db CopyDist28Len
		dw CopyDist28
		db CopyDist29Len
		dw CopyDist29
		db ThrowInlineLen
		dw ThrowInline
		db ThrowInlineLen
		dw ThrowInline

; For all of these routines, the calling convention is like this:
; bc = length of the to-be-copied block
; 'c = bit reader state
; 'de = InputBufPos
; 'hl = OutputBufPos
; iy = Write_AndNext

; Distance alphabet symbols 0-29
CopyDist0:	push hl
		exx
		ld de,1 - 1
		jp Copy_AndNext
CopyDist0Len:	equ $ - CopyDist0

CopyDist1:	push hl
		exx
		ld de,2 - 1
		jp Copy_AndNext
CopyDist1Len:	equ $ - CopyDist1

CopyDist2:	push hl
		exx
		ld de,3 - 1
		jp Copy_AndNext
CopyDist2Len:	equ $ - CopyDist2

CopyDist3:	push hl
		exx
		ld de,4 - 1
		jp Copy_AndNext
CopyDist3Len:	equ $ - CopyDist3

CopyDist4:	call Read1Bit
		add a,5 - 1
		jp CopySmallDist
CopyDist4Len:	equ $ - CopyDist4

CopyDist5:	call Read1Bit
		add a,7 - 1
		jp CopySmallDist
CopyDist5Len:	equ $ - CopyDist5

CopyDist6:	call Read2Bits
		add a,9 - 1
		jp CopySmallDist
CopyDist6Len:	equ $ - CopyDist6

CopyDist7:	call Read2Bits
		add a,13 - 1
		jp CopySmallDist
CopyDist7Len:	equ $ - CopyDist7

CopyDist8:	call Read3Bits
		add a,17 - 1
		jp CopySmallDist
CopyDist8Len:	equ $ - CopyDist8

CopyDist9:	call Read3Bits
		add a,25 - 1
		jp CopySmallDist
CopyDist9Len:	equ $ - CopyDist9

CopyDist10:	call Read4Bits
		add a,33 - 1
		jp CopySmallDist
CopyDist10Len:	equ $ - CopyDist10

CopyDist11:	call Read4Bits
		add a,49 - 1
		jp CopySmallDist
CopyDist11Len:	equ $ - CopyDist11

CopyDist12:	call Read5Bits
		add a,65 - 1
		jp CopySmallDist
CopyDist12Len:	equ $ - CopyDist12

CopyDist13:	call Read5Bits
		add a,97 - 1
		jp CopySmallDist
CopyDist13Len:	equ $ - CopyDist13

CopyDist14:	call Read6Bits
		add a,129 - 1
		jp CopySmallDist
CopyDist14Len:	equ $ - CopyDist14

CopyDist15:	call Read6Bits
		add a,193 - 1
		jp CopySmallDist
CopyDist15Len:	equ $ - CopyDist15

CopyDist16:	call Read7Bits
		push hl
		exx
		ld e,a
		ld d,257 - 1 >> 8
		jp Copy_AndNext
CopyDist16Len:	equ $ - CopyDist16

CopyDist17:	call Read7Bits
		push hl
		exx
		add a,385 - 1 & 0FFH
		ld e,a
		ld d,385 - 1 >> 8
		jp Copy_AndNext
CopyDist17Len:	equ $ - CopyDist17

CopyDist18:	call Read8Bits
		push hl
		exx
		ld e,a
		ld d,513 - 1 >> 8
		jp Copy_AndNext
CopyDist18Len:	equ $ - CopyDist18

CopyDist19:	call Read8Bits
		push hl
		exx
		ld e,a
		ld d,769 - 1 >> 8
		jp Copy_AndNext
CopyDist19Len:	equ $ - CopyDist19

CopyDist20:	call Read8Bits
		ex af,af'
		call Read1Bit
		add a,1025 - 1 >> 8
		jp CopyBigDist
CopyDist20Len:	equ $ - CopyDist20

CopyDist21:	call Read8Bits
		ex af,af'
		call Read1Bit
		add a,1537 - 1 >> 8
		jp CopyBigDist
CopyDist21Len:	equ $ - CopyDist21

CopyDist22:	call Read8Bits
		ex af,af'
		call Read2Bits
		add a,2049 - 1 >> 8
		jp CopyBigDist
CopyDist22Len:	equ $ - CopyDist22

CopyDist23:	call Read8Bits
		ex af,af'
		call Read2Bits
		add a,3073 - 1 >> 8
		jp CopyBigDist
CopyDist23Len:	equ $ - CopyDist23

CopyDist24:	call Read8Bits
		ex af,af'
		call Read3Bits
		add a,4097 - 1 >> 8
		jp CopyBigDist
CopyDist24Len:	equ $ - CopyDist24

CopyDist25:	call Read8Bits
		ex af,af'
		call Read3Bits
		add a,6145 - 1 >> 8
		jp CopyBigDist
CopyDist25Len:	equ $ - CopyDist25

CopyDist26:	call Read8Bits
		ex af,af'
		call Read4Bits
		add a,8193 - 1 >> 8
		jp CopyBigDist
CopyDist26Len:	equ $ - CopyDist26

CopyDist27:	call Read8Bits
		ex af,af'
		call Read4Bits
		add a,12289 - 1 >> 8
		jp CopyBigDist
CopyDist27Len:	equ $ - CopyDist27

CopyDist28:	call Read8Bits
		ex af,af'
		call Read5Bits
		add a,16385 - 1 >> 8
		jp CopyBigDist
CopyDist28Len:	equ $ - CopyDist28

CopyDist29:	call Read8Bits
		ex af,af'
		call Read5Bits
		add a,24577 - 1 >> 8
		jp CopyBigDist
CopyDist29Len:	equ $ - CopyDist29

; a = distance - 1
CopySmallDist:	push hl
		exx
		ld e,a
		ld d,0
		jp Copy_AndNext

; a  = MSB(distance - 1)
; a' = LSB(distance - 1)
CopyBigDist:	push hl
		exx
		ld d,a
		ex af,af'
		ld e,a
		jp Copy_AndNext


; -- Routines to read bits and bytes from the GZ file --

; (Re-)fill the input buffer with data from the .gz file
FillInBuffer:	ld a,(InFileHandle)
		ld b,a
		ld de,InputBuffer
		ld hl,InputBufSize
		ld c,#48	; _READ
		call #0005	; BDOS
		cp #C7		; .EOF
		jp nz,CheckDOSError
		ld (InputEof),a	; any non-zero value
		ret


; For speed reasons all the ReadXX functions below require register C and DE
; to contains certain values (and those functions also update C, DE). This
; function sets up the correct values in C and DE.
PrepareRead:	ld a,(InputBits)
		ld c,a
		ld de,(InputBufPos)
		ret

; After you're done calling the ReadXX functions and you want to use regsiters
; C and DE for other stuff again. They should be written back to memory.
FinishRead:	ld (InputBufPos),de
		ld a,c
		ld (InputBits),a
		ret


; Read a byte from the input
; Requires: regsiter DE contains 'InputBufPos' (in/out)
; a <- value
; Unchanged: bc, hl, ix, iy
ReadByte:	ld a,(de)
		inc e
		ret nz		; crosses 256-byte boundary?
		push af
		inc d
		ld a,d
		cp InputBufferEnd >> 8
		jr z,NextBlock	; end of input buffer reached?
		pop af
		ret

NextBlock:	push bc
		push hl
		ld a,(InputEof)
		or a
		jr nz,EofError
		call FillInBuffer
		pop hl
		pop bc
		ld a,(InputEof)
		or a
		ld de,InputBuffer
		jr z,NoTrap
		ld de,InputBufferEnd - 1 ; Trap on next read
NoTrap		pop af
		ret

EofError:	ld hl,TextEofErr
		call ThrowMessage


; Read a single bit from the input.
; This code fragment is generated by 'GenerateHuffman'
; Requires: PrepareRead has been called (registers C and DE are reserved)
; output: carry-flag, reset -> read 0-bit, set-> read 1-bit
; Modifies: a
; Unchanged: b, hl, ix, iy
ReadBitInlineA:	MACRO
		srl c
		call z,ReadBitA	; if sentinel bit is shifted out
		ENDM

; 'outline' part of ReadBitInlineA
ReadBitA:	call ReadByte
		scf  ; set sentinel bit
		rra
		ld c,a
		ret

; Similar to ReadBitInlineA, but changes regsiter B instead of A (is a tiny bit
; slower because of that).
ReadBitInlineB: MACRO
		srl c
		call z,ReadBitB  ; if sentinel bit is shifted out
		ENDM

; 'outline' part of ReadBitInlineB
ReadBitB:	ld b,a
		call ReadByte
		scf  ; set sentinel bit
		rra
		ld c,a
		ld a,b
		ret

; Routines to read {1..8} bits from the input.
; Requires: PrepareRead has been called (registers C and DE are reserved)
; a <- value
; Modifies: b
; Unchanged: hl, ix, iy
Read1Bit:	xor a
		ReadBitInlineB
		rla
		ret

Read2Bits:	xor a
		ReadBitInlineB
		rra
		ReadBitInlineB
		rla
		rla
		ret

Read3Bits:	xor a
		ReadBitInlineB
		rra
		ReadBitInlineB
		rra
		ReadBitInlineB
		rla
		rla
		rla
		ret

Read4Bits:	xor a
		ReadBitInlineB
		rra
		ReadBitInlineB
		rra
		ReadBitInlineB
		rra
		ReadBitInlineB
		rla
		rla
		rla
		rla
		ret

Read5Bits:	xor a
		ReadBitInlineB
		rra
		ReadBitInlineB
		rra
		ReadBitInlineB
		rra
		ReadBitInlineB
		rra
		ReadBitInlineB
		rra
		rra
		rra
		rra
		ret

Read6Bits:	xor a
		ReadBitInlineB
		rra
		ReadBitInlineB
		rra
		ReadBitInlineB
		rra
		ReadBitInlineB
		rra
		ReadBitInlineB
		rra
		ReadBitInlineB
		rra
		rra
		rra
		ret

Read7Bits:	xor a
		ReadBitInlineB
		rra
		ReadBitInlineB
		rra
		ReadBitInlineB
		rra
		ReadBitInlineB
		rra
		ReadBitInlineB
		rra
		ReadBitInlineB
		rra
		ReadBitInlineB
		rra
		rra
		ret

Read8Bits:	ReadBitInlineB
		rra
		ReadBitInlineB
		rra
		ReadBitInlineB
		rra
		ReadBitInlineB
		rra
		ReadBitInlineB
		rra
		ReadBitInlineB
		rra
		ReadBitInlineB
		rra
		ReadBitInlineB
		rra
		ret


; -- Routines to write to the output file --
; --   they also maintain a sliding window to the last 32kB
; --   and they calculate a CRC32 value of the data

; Write a byte to the output.
; This routine is very tightly coupled to the huffman decode routines. In fact
; it's not really a function at all. Instead of returning it jumps to
; 'LiteralTree'. And because of this, this function should not be called, but
; jumped to.
;
; a = value
; hl = OutputBufPos (in/out)
; Modifies: a
Write_AndNext:	ld (hl),a
		inc l
		jp nz,LiteralTree	; crosses 256-byte boundary?

		inc h
		ld a,h
		cp OutputBufEnd >> 8
		jp nz,LiteralTree	; end of buffer reached?

		ld (OutputBufPos),hl	; OutputBufEnd
		call FinishBlock
		; hl = OutputBufPos = OutputBuffer
		jp LiteralTree

; Repeat (copy) a chunk of data that was written before.
; Like 'Write_AndNext' above, this routine is very tightly coupled to the
; huffman decode routines. It does not return, instead it jumps to LiteralTree.
; (top-of-stack) = OutputBufPos (in/out)
; bc = byte count (range 3-258)
; de = distance - 1
; Modifies: (after exx) af, bc', de', hl'
Copy_AndNext:	pop hl   ; hl = OutputBufPos
		push hl
		scf
		sbc hl,de
		pop de
		ld a,h
		jr c,CopyWrap
		cp OutputBuffer >> 8
		jr c,CopyWrap
WrapContinue:	ld a,(OutputBufEnd >> 8) - 3
		cp h  ; does the source have a 512 byte margin without wrapping?
		jr c,CopySlow
		cp d  ; does the destination a 512 byte margin without wrapping?
		jr c,CopySlow
		ldi
		ldi
		ldir
		push de
		; and next
		exx
		pop hl	; updated OutputBufPos
		jp LiteralTree

CopyWrap:	add a,OutputBufSize >> 8
		ld h,a
		jp WrapContinue

; bc = byte count
; hl = buffer source
; de = buffer destination
; Modifies: af, bc, de, hl
CopySlow:	ld (OutputBufPos),de
		ld e,l
		ld d,h
		add hl,bc
		jr c,CopySplit
		ld a,h
		cp OutputBufEnd >> 8
		jp c,WrBlk_AndNext
; hl = end address
CopySplit:	push bc
		ld bc,OutputBufEnd
		and a
		sbc hl,bc  ; hl = bytes past end
		ex (sp),hl
		pop bc
		push bc
		sbc hl,bc  ; hl = bytes until end
		ld c,l
		ld b,h
		call WriteBlock
		pop bc
		ld hl,OutputBuffer
		ld a,b
		or c
		jp nz,CopySlow
		; and next
		exx
		ld hl,(OutputBufPos)
		jp LiteralTree

WrBlk_AndNext:	call WriteBlock
		; and next
		exx
		ld hl,(OutputBufPos)
		jp LiteralTree

; bc = byte count
; de = source
; Modifies: af, bc, de, hl
WriteBlock:	ld hl,(OutputBufPos)
		add hl,bc
		jr c,CopySplit2
		ld a,h
		cp OutputBufEnd >> 8
		jr nc,CopySplit2
		and a
		sbc hl,bc
		ex de,hl
		ldir
		ld (OutputBufPos),de
		ret

; hl = end address
CopySplit2:	push bc
		ld bc,OutputBufEnd
		and a
		sbc hl,bc  ; hl = bytes past end
		ld c,l
		ld b,h
		ex (sp),hl
		sbc hl,bc  ; hl = bytes until end
		ld c,l
		ld b,h
		ex de,hl
		ld de,(OutputBufPos)
		ldir
		ld (OutputBufPos),de
		push hl
		call FinishBlock
		pop de
		pop bc
		ld a,b
		or c
		jp nz,WriteBlock
		ret

; a = value
; de,bc <- unchanged
WriteByte:	ld (hl),a
		inc l
		ret nz		; crosses 256-byte boundary?

		inc h
		ld a,h
		cp OutputBufEnd >> 8
		ret nz		; end of buffer reached?

		ld (OutputBufPos),hl	; OutputBufEnd
		;jp FinishBlock
		; hl = OutputBufPos = OutputBuffer


; 'Finish' the data in the (fully or partially filled) OutputBuffer. This is
;  - update OutputCount
;  - update Crc32Value
;  - write the data to disk
;  - reinitialize OutputBufPos
; hl <- OutputBuffer
FinishBlock:	push bc
		push de

		ld hl,(OutputBufPos)
		ld bc,OutputBuffer
		or a
		sbc hl,bc	; hl = #bytes in OutputBuffer
		jr z,FinishBlockEnd	; any data present?

; Increase count
		push hl
		ld bc,(OutputCount + 0)
		add hl,bc
		ld (OutputCount + 0),hl
		jr nc,SkipInc64
		ld hl,(OutputCount + 2)
		inc hl
		ld (OutputCount + 2),hl
SkipInc64:

; Update CRC32
		ld a,(NoCrcCheck)
		or a
		jr nz,SkipCrcUpdate
		ld hl,OutputBuffer
		pop bc		; bc = #bytes in OutputBuffer
		push bc
		exx
		push bc
		push de
		push hl
		ld de,(Crc32Value + 0)
		ld bc,(Crc32Value + 2)	; bc:de = old crc value (32-bit)
		exx
		ld a,c  ; convert 16-bit counter bc to two 8-bit counters in b and c
		dec bc
		inc b
		ld c,b
		ld b,a
CRC32Loop:	ld a,(hl)
		inc hl
		exx
		xor e
		ld l,a
		ld h,CRC32Table >> 8
		ld a,(hl)
		xor d
		ld e,a
		inc h
		ld a,(hl)
		xor c
		ld d,a
		inc h
		ld a,(hl)
		xor b
		ld c,a
		inc h
		ld b,(hl)
		exx
		djnz CRC32Loop
		dec c
		jp nz,CRC32Loop
		exx
		ld (Crc32Value + 0),de
		ld (Crc32Value + 2),bc	; store updated crc value (32-bit)
		pop hl
		pop de
		pop bc
		exx
SkipCrcUpdate:

; check for CTRL-C
		ld c,#0B	; _CONST
		call #0005	; BDOS

; Write data to file
		ld de,OutputBuffer
		pop hl		; hl = #bytes in OutputBuffer
		ld a,(OutFileHandle)
		ld b,a
		inc a
		jr z,FinishBlockEnd	; only testing (not writing to file)?
		ld c,#49	; _WRITE
		call #0005	; BDOS
		call CheckDOSError

FinishBlockEnd:	pop de
		pop bc
		ld hl,OutputBuffer
		ld (OutputBufPos),hl
		ret


; === Utility functions ===

; a <- DOS error code
CheckDOSError:	and a
		ret z		; 0 -> no error
		ld b,a
		ld de,CliBuffer
		ld c,#66	; _EXPLAIN
		call #0005	; BDOS
		ld hl,CliBuffer
		call PrintLn
		jr DosExit

; hl <- message
ExitWithError:	call Print
DosExit:	ld bc,1 * 256 + #62	; _TERM
		jp #0005		; BDOS


; hl = value
PrintHexHL:	ld a,h
		push hl
		call PrintHexA
		pop hl
		ld a,l
		;jr PrintHexA

; a = value
PrintHexA:	push af
		rrca
		rrca
		rrca
		rrca
		call PrintHexNibble
		pop af
		;jr PrintHexNibble

; a = value, uses lower nibble
PrintHexNibble:	and #0F
		cp 10
		ccf
		adc a,"0"
		daa
		;jr PrintChar

; a = character
PrintChar:	ld iy,(#FCC0)	; EXPTBL-1
		ld ix,#00A2	; CHPUT
		jp #001C	; CALSLT

; hl = string (0-terminated)
PrintLn:	call Print
PrintCrLf:	ld hl,TextCrLf
		;jr Print

; hl = string (0-terminated)
Print:		ld a,(hl)
		inc hl
		and a
		ret z
		push hl
		call PrintChar
		pop hl
		jr Print

ThrowException:	pop de	; return address
		call PrintException
		jr DosExit

; hl = message
ThrowMessage:	pop de	; return address
		push hl
		call PrintException
		pop hl
		call PrintLn
		jr DosExit

; de = return address
PrintException:	push de
		ld hl,TextException
		call Print
		pop hl
		dec hl
		dec hl
		dec hl	; before call
		call PrintHexHL
		jr PrintCrLf


; === variables ===
; -- Set by parsing the gzip header --
HeaderFlags:	db 0

; -- Filled in by parsing the command line --
InputPath:	dw 0	; zero-terminated string to input filename
OutputPath:	dw 0	; zero terminated string to output filename (optional)
Quiet:		db 0	; non-zero when running in 'quite' mode
NoCrcCheck:     db 0	; non-zero when running without crc check

; -- Used during building the dynamic alphabet --
; Strictly speaking we only need to store the LSB of the following two values.
; But also storing the MSB allows for simpler code, so the space overhead here
; is more than made up in smaller code size.
hlit:		dw 256	; MSB fixed at '1'
hdist:		dw 0	; MSB fixed at '0'

; -- Used during GenerateHuffman --
HuffRoot:	dw 0
LengthsPtr:	dw 0
HuffOutPtr:	dw 0

; -- Used for reading the input file --
InputEof:	db 0		; non-zero when end-of-file reached
InFileHandle:	db #FF
InputBufPos:	dw InputBuffer
InputBits:	db 0		; partially consumed byte, 0 -> start new byte

; -- Used for writing the output file
OutputCount:	ds 4		; 32-bit value
Crc32Value:	ds 4,#FF	; 32-bit value
OutFileHandle:	db #FF		; start with invalid file handle
OutputBufPos:	dw OutputBuffer


; === strings ===
TextWelcome:	db "Gunzip 1.0 by Grauw", 13, 10, 10, 0
TextInflating:	db "Inflating ", 0
TextTesting:	db "Testing ",0
TextDotDotDot:	db "..."
TextCrLf:	db 13, 10, 0
TextNeedDos2:	db "MSX-DOS 2 is required.",13, 10, 0
TextNoMemory:	db "Insufficient TPA space.", 13, 10, 0
TextUsage:	db "Usage: gunzip [options] <archive.gz> <outputfile>", 13, 10
		db 13, 10
		db "Options:", 13, 10
		db "  /q  Quiet, suppress messages.", 13, 10
		db "  /f  Fast, no checksum validation.", 13, 10
		db 13, 10
		db "If no output file is specified, the archive will be tested.", 13, 10, 0
TextNotGzip:	db "Not a GZIP file.", 13, 10, 0
TextNotDeflate: db "Not compressed with DEFLATE.", 13, 10, 0
TextUnknownFlag:db "Unknown flag.", 13, 10, 0
TextSizeError:	db "Inflated size mismatch.", 13, 10, 0
TextCrcError:	db "Inflated CRC32 mismatch.", 13, 10, 0
TextException:	db "An exception occurred on address: ", 0
TextOptionErr:	db "Unknown command line option.", 13, 10, 0
TextPathErr:	db "Can not specify additional file paths.", 13, 10, 0
TextParameters:	db "PARAMETERS", 0
TextBlockErr:	db "Invalid block type.", 13, 10, 0
TextLengthErr:	db "Invalid length.", 13, 10, 0
TextEofErr:	db "Premature end of data.", 13, 10, 0


; === Constant tables ===

; -- Used during dynamic alphabet building
HeaderCodeOrder:db 16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15


; -- The fixed alphabet --
; Lengths of the literal symbols
FixedLitLen:	db 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8  ; 0-143: 8
		db 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8
		db 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8
		db 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8
		db 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8
		db 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8
		db 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9  ; 144-255: 9
		db 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9
		db 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9
		db 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9
		db 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 7, 7, 7, 7, 7, 7, 7, 7  ; 256-279: 7
		db 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 8, 8, 8, 8, 8, 8, 8, 8  ; 280-287: 8
FixedLitCount:	equ $ - FixedLitLen

; Lengths of the distance symbols
FixedDistLen:	db 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5
		db 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5
FixedDistCount: equ $ - FixedDistLen


; -- CRC32 lookup table, must be 256-byte aligned --
		ds (256 - ($ & 255) & 255)
CRC32Table:	; uint32_t[256]
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


; === Buffers ===

EOP:		equ $	; end-of-program, buffers can start here

; -- ParseCLI --
; buffer that holds command line and in/out filenames,
; can be reused once files are opened
CliBuffer:	equ EOP		; ds 255


; -- BuildDynAlpha --
; union {
;     HdrCodeLengths      ds MAX_HEADER_LEN
;     struct {
;         LLDCodeLengths  ds MAX_LIT_LEN + MAX_DIST_LEN
;         HeaderTree      ds (8 + 5) * (MAX_HEADER_LEN - 1)
;     }
; }
; These 3 buffers are only needed during BuildDynAlpha, though LLDCodeLengths
; cannot overlap with LiteralTree and DistanceTree

HdrCodeLSize:	equ MAX_HEADER_LEN
LLDCodeLSize:	equ MAX_LIT_LEN + MAX_DIST_LEN
HeaderTreeSize:	equ (8 + 5) * (MAX_HEADER_LEN - 1)

HdrCodeLengths:	equ EOP					; ds HdrCodeLSize
LLDCodeLengths:	equ EOP					; ds LLDCodeLSize
HeaderTree:	equ LLDCodeLengths + LLDCodeLSize	; ds HeaderTreeSize

HeaderTreeEnd:	equ HeaderTree + HeaderTreeSize


; -- Generated literal/distance huffman trees
; These cannot overlap LLDCodeLengths, but overlapping HeaderTree is fine
LiteralTreeSize:equ (8 +  5) * (288 - 1)
LiteralTree:	equ HeaderTree
LiteralTreeEnd:	equ LiteralTree + LiteralTreeSize

DistTreeSize:	equ (8 + 12) * (32 - 1) + 1
DistanceTree:	equ LiteralTreeEnd
DistanceTreeEnd:equ DistanceTree + DistTreeSize

; -- Input and output file buffers
; These must be aligned at 256-byte boundary. OutputBuffer must be exactly
; 32kB. InputBuffer must be (any) multiple of 256 bytes, but bigger improves
; read performance.
Padding		equ (256 - (DistanceTreeEnd & 255)) & 255

OutputBufSize:	equ #8000	; _must_ be exactly 32kB
OutputBuffer:	equ DistanceTreeEnd + Padding
OutputBufEnd:	equ OutputBuffer + OutputBufSize

InputBufSize:	equ #1000
InputBuffer:	equ OutputBufEnd
InputBufferEnd:	equ InputBuffer + InputBufSize

; -- Huffman scratch area --
; Used while generating Huffman decoder.  TODO maybe overlap with 'Padding'?
HuffScratchSize:equ 32
HuffScratch:	equ InputBufferEnd
HuffScratchEnd:	equ HuffScratch + HuffScratchSize

MemoryEnd:	equ HuffScratchEnd
