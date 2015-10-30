;
; Memory buffer reader
;
Reader: MACRO
	; ix = this
	; a <- value
	Read:
		ld a,(0)
	bufferPosition: equ $ - 2
		inc (ix + Reader.bufferPosition)
		ret nz
		jp Reader_Read.Continue

	endOfData:
		db 0
	bits:
		db 0
	fileHandle:
		db 0FFH
	_size:
	ENDM

Reader_class: Class Reader, Reader_template, Heap_main
Reader_template: Reader

; de = file path
; ix = this
; ix <- this
; de <- this
Reader_Construct:
	ld hl,IBUFFER
	ld (ix + Reader.bufferPosition),l
	ld (ix + Reader.bufferPosition + 1),h

	ld a,00000001B  ; read only
	call DOS_OpenFileHandle
	call Application_CheckDOSError
	ld (ix + Reader.fileHandle),b
	call Reader_FillBuffer
	ld e,ixl
	ld d,ixh
	ret

; ix = this
; ix <- this
Reader_Destruct:
	ld b,(ix + Reader.fileHandle)
	call DOS_CloseFileHandle
	jp Application_CheckDOSError

; ix = this
; a <- value
; Modifies: none
Reader_Read: PROC
	jp ix
Continue:
	push af
	ld a,(ix + Reader.bufferPosition + 1)
	inc a
	cp IBUFFER_END >> 8
	call z,NextBlock
	ld (ix + Reader.bufferPosition + 1),a
	pop af
	ret
NextBlock:
	push bc
	push de
	push hl
	bit 0,(ix + Reader.endOfData)
	ld hl,Reader_endOfDataError
	call nz,System_ThrowExceptionWithMessage
	call Reader_FillBuffer
	pop hl
	pop de
	pop bc
	bit 0,(ix + Reader.endOfData)
	ld a,IBUFFER >> 8	; bufferStart
	ret z
TrapNextRead:
	ld (ix + Reader.bufferPosition),0FFH
	ld a,IBUFFER_END_HIGH - 1
	ret
	ENDP

; ix = this
; Modifies: af, bc, de, hl
Reader_FillBuffer: PROC
	call DOS_ConsoleStatus  ; allow ctrl-c
	ld b,(ix + Reader.fileHandle)
	ld de,IBUFFER
	ld hl,IBUFFER_SIZE
	call DOS_ReadFromFileHandle
	cp .EOF
	jp nz,Application_CheckDOSError
	;jp Reader_MarkEndOfData
	ENDP

Reader_MarkEndOfData:
	ld (ix + Reader.endOfData),1
	ret

; bc = nr of bytes to skip
; ix = this
; Modifies: bc, a
Reader_Skip:
	call Reader_Read
	dec bc
	ld a,b
	or c
	jr nz,Reader_Skip
	ret

; ix = this
; f <- c: bit
; Modifies: none
Reader_ReadBit:
	srl (ix + Reader.bits)
	ret nz  ; return if sentinel bit is still present
	push bc
	ld c,a
	call Reader_Read
	scf  ; set sentinel bit
	rra
	ld (ix + Reader.bits),a
	ld a,c
	pop bc
	ret

; c <- inline bit reader state
Reader_PrepareReadBitInline:
	ld c,(ix + Reader.bits)
	ret

; c = inline bit reader state
Reader_FinishReadBitInline:
	ld (ix + Reader.bits),c
	ret

; c = inline bit reader state
; c <- inline bit reader state
; f <- c: bit
; Modifies: a
Reader_ReadBitInline: MACRO
	srl c
	call z,Reader_ReadBitInline_NextByte  ; if sentinel bit is shifted out
	ENDM

; c <- inline bit reader state
; f <- c: bit
; Modifies: a
Reader_ReadBitInline_NextByte:
	call Reader_Read
	scf  ; set sentinel bit
	rra
	ld c,a
	ret

; c = inline bit reader state
; c <- inline bit reader state
; f <- c: bit
; Modifies: b
Reader_ReadBitInline_B: MACRO
	srl c
	call z,Reader_ReadBitInline_B_NextByte  ; if sentinel bit is shifted out
	ENDM

; c <- inline bit reader state
; f <- c: bit
; Modifies: b
Reader_ReadBitInline_B_NextByte:
	ld b,a
	call Reader_Read
	scf  ; set sentinel bit
	rra
	ld c,a
	ld a,b
	ret

; c = inline bit reader state
; a <- value
; c <- inline bit reader state
; Modifies: b
Reader_ReadBitsInline_1:
	xor a
	Reader_ReadBitInline_B
	rla
	ret

Reader_ReadBitsInline_2:
	xor a
	Reader_ReadBitInline_B
	rra
	Reader_ReadBitInline_B
	rla
	rla
	ret

Reader_ReadBitsInline_3:
	xor a
	Reader_ReadBitInline_B
	rra
	Reader_ReadBitInline_B
	rra
	Reader_ReadBitInline_B
	rla
	rla
	rla
	ret

Reader_ReadBitsInline_4:
	xor a
	Reader_ReadBitInline_B
	rra
	Reader_ReadBitInline_B
	rra
	Reader_ReadBitInline_B
	rra
	Reader_ReadBitInline_B
	rla
	rla
	rla
	rla
	ret

Reader_ReadBitsInline_5:
	xor a
	Reader_ReadBitInline_B
	rra
	Reader_ReadBitInline_B
	rra
	Reader_ReadBitInline_B
	rra
	Reader_ReadBitInline_B
	rra
	Reader_ReadBitInline_B
	rra
	rra
	rra
	rra
	ret

Reader_ReadBitsInline_6:
	xor a
	Reader_ReadBitInline_B
	rra
	Reader_ReadBitInline_B
	rra
	Reader_ReadBitInline_B
	rra
	Reader_ReadBitInline_B
	rra
	Reader_ReadBitInline_B
	rra
	Reader_ReadBitInline_B
	rra
	rra
	rra
	ret

Reader_ReadBitsInline_7:
	xor a
	Reader_ReadBitInline_B
	rra
	Reader_ReadBitInline_B
	rra
	Reader_ReadBitInline_B
	rra
	Reader_ReadBitInline_B
	rra
	Reader_ReadBitInline_B
	rra
	Reader_ReadBitInline_B
	rra
	Reader_ReadBitInline_B
	rra
	rra
	ret

Reader_ReadBitsInline_8:
	Reader_ReadBitInline_B
	rra
	Reader_ReadBitInline_B
	rra
	Reader_ReadBitInline_B
	rra
	Reader_ReadBitInline_B
	rra
	Reader_ReadBitInline_B
	rra
	Reader_ReadBitInline_B
	rra
	Reader_ReadBitInline_B
	rra
	Reader_ReadBitInline_B
	rra
	ret

; b = nr of bits to read (1-8)
; ix = this
; a <- value
; Modifies: af, bc
Reader_ReadBits: PROC
	ld c,1
	xor a
Loop:
	call Reader_ReadBit
	jr nc,Zero
	add a,c
Zero:
	rlc c
	djnz Loop
	ret
	ENDP

; b = nr of bits to read (1-8)
; iy = this
; a <- value
; Modifies: af, bc
Reader_ReadBits_IY:
	push iy
	ex (sp),ix
	call Reader_ReadBits
	pop ix
	ret

; ix = this
Reader_Align:
	ld (ix + Reader.bits),0
	ret

;
Reader_endOfDataError:
	db "Premature end of data.",13,10,0
