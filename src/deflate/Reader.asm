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

	bufferStart:
		dw 0
	bufferSize:
		dw 0
	bufferEnd:
		dw 0
	filler:
		dw Reader_MarkEndOfData
	endOfData:
		db 0
	bits:
		db 0
	_size:
	ENDM

Reader_class: Class Reader, Reader_template, Heap_main
Reader_template: Reader

; hl = buffer start
; bc = buffer size
; ix = this
; ix <- this
; de <- this
Reader_Construct:
	ld a,l  ; check if buffer is 256-byte aligned
	or c
	call nz,System_ThrowException
	ld (ix + Reader.bufferStart),l
	ld (ix + Reader.bufferStart + 1),h
	ld (ix + Reader.bufferSize),c
	ld (ix + Reader.bufferSize + 1),b
	ld (ix + Reader.bufferPosition),l
	ld (ix + Reader.bufferPosition + 1),h
	add hl,bc
	ld (ix + Reader.bufferEnd),l
	ld (ix + Reader.bufferEnd + 1),h
	ld e,ixl
	ld d,ixh
	ret

; ix = this
; ix <- this
Reader_Destruct:
	ret

; ix = this
; a <- value
; Modifies: none
Reader_Read: PROC
	jp ix
Continue:
	push af
	ld a,(ix + Reader.bufferPosition + 1)
	inc a
	cp (ix + Reader.bufferEnd + 1)
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
	ld a,(ix + Reader.bufferStart + 1)
	ret z
TrapNextRead:
	ld (ix + Reader.bufferPosition),0FFH
	ld a,(ix + Reader.bufferEnd + 1)
	dec a
	ret
	ENDP

; ix = this
; Modifies: af, bc, de, hl
Reader_FillBuffer:
	ld l,(ix + Reader.filler)
	ld h,(ix + Reader.filler + 1)
	jp hl

; ix = this
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
