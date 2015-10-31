;
; Memory buffer reader
;

Reader_endOfData:
	db 0
Reader_fileHandle:
	db 0FFH
Reader_bufPos:
	dw IBUFFER
Reader_bits:
	db 0

;----
; de = Reader_bufPos
; a <- value
Reader_Read_DE_fast: PROC
	ld a,(de)
	inc e
	ret nz
	push af
	inc d
	ld a,d
	cp IBUFFER_END >> 8
	jr z,NextBlock
	pop af
	ret

NextBlock:
	push bc
	push de
	push hl
	ld a,(Reader_endOfData)
	or a
	jr nz,EofError
	call Reader_FillBuffer
	pop hl
	pop de
	pop bc
	ld a,(Reader_endOfData)
	or a
	ld d,IBUFFER >> 8	; bufferStart
	jr nz,Trap
	pop af
	ret

Trap:	; trap next read
	ld de,IBUFFER_END-1
	pop af
	ret

EofError:
	ld hl,Reader_endOfDataError
	call System_ThrowExceptionWithMessage
	ENDP


; de = file path
Reader_Construct:
	ld a,00000001B  ; read only
	ld c,43H; _OPEN
	call BDOS
	call Application_CheckDOSError
	ld a,b
	ld (Reader_fileHandle),a

	jr Reader_FillBuffer


Reader_Destruct:
	ld a,(Reader_fileHandle)
	ld b,a
	ld c,45H ; _CLOSE
	call BDOS
	jp Application_CheckDOSError

; Modifies: af, bc, de, hl
Reader_FillBuffer:
	ld a,(Reader_fileHandle)
	ld b,a
	ld de,IBUFFER
	ld hl,IBUFFER_SIZE
	ld c,48H ; _READ
	call BDOS
	cp 0C7H ; .EOF
	jp nz,Application_CheckDOSError
	ld (Reader_endOfData),a	; any non-zero value
	ret

; hl = nr of bytes to skip
; Modifies: bc, a
Reader_Skip_DE:
	call Reader_Read_DE_fast
	dec hl
	ld a,h
	or l
	jr nz,Reader_Skip_DE
	ret

; c <- inline bit reader state
; de <- inline Reader_bufPos
Reader_PrepareReadBitInline:
	ld a,(Reader_bits)
	ld c,a
	ld de,(Reader_bufPos)
	ret

; c = inline bit reader state
; de = inline Reader_bufPos
Reader_FinishReadBitInline:
	ld (Reader_bufPos),de
	ld a,c
	ld (Reader_bits),a
	ret

; c = inline bit reader state
; de = inline Reader_bufPos
; c <- inline bit reader state
; f <- c: bit
; Modifies: a
Reader_ReadBitInline_DE: MACRO
	srl c
	call z,Reader_ReadBitInline_NextByte_DE  ; if sentinel bit is shifted out
	ENDM

; c <- inline bit reader state
; de = inline Reader_bufPos
; f <- c: bit
; Modifies: a
Reader_ReadBitInline_NextByte_DE:
	call Reader_Read_DE_fast
	scf  ; set sentinel bit
	rra
	ld c,a
	ret

; c = inline bit reader state
; de = inline Reader_bufPos
; c <- inline bit reader state
; f <- c: bit
; Modifies: b
Reader_ReadBitInline_B_DE: MACRO
	srl c
	call z,Reader_ReadBitInline_B_NextByte_DE  ; if sentinel bit is shifted out
	ENDM

; c <- inline bit reader state
; de = inline Reader_bufPos
; f <- c: bit
; Modifies: b
Reader_ReadBitInline_B_NextByte_DE:
	ld b,a
	call Reader_Read_DE_fast
	scf  ; set sentinel bit
	rra
	ld c,a
	ld a,b
	ret

; c = inline bit reader state
; de = inline Reader_bufPos
; a <- value
; c <- inline bit reader state
; Modifies: b
Reader_ReadBitsInline_1_DE:
	xor a
	Reader_ReadBitInline_B_DE
	rla
	ret

Reader_ReadBitsInline_2_DE:
	xor a
	Reader_ReadBitInline_B_DE
	rra
	Reader_ReadBitInline_B_DE
	rla
	rla
	ret

Reader_ReadBitsInline_3_DE:
	xor a
	Reader_ReadBitInline_B_DE
	rra
	Reader_ReadBitInline_B_DE
	rra
	Reader_ReadBitInline_B_DE
	rla
	rla
	rla
	ret

Reader_ReadBitsInline_4_DE:
	xor a
	Reader_ReadBitInline_B_DE
	rra
	Reader_ReadBitInline_B_DE
	rra
	Reader_ReadBitInline_B_DE
	rra
	Reader_ReadBitInline_B_DE
	rla
	rla
	rla
	rla
	ret

Reader_ReadBitsInline_5_DE:
	xor a
	Reader_ReadBitInline_B_DE
	rra
	Reader_ReadBitInline_B_DE
	rra
	Reader_ReadBitInline_B_DE
	rra
	Reader_ReadBitInline_B_DE
	rra
	Reader_ReadBitInline_B_DE
	rra
	rra
	rra
	rra
	ret

Reader_ReadBitsInline_6_DE:
	xor a
	Reader_ReadBitInline_B_DE
	rra
	Reader_ReadBitInline_B_DE
	rra
	Reader_ReadBitInline_B_DE
	rra
	Reader_ReadBitInline_B_DE
	rra
	Reader_ReadBitInline_B_DE
	rra
	Reader_ReadBitInline_B_DE
	rra
	rra
	rra
	ret

Reader_ReadBitsInline_7_DE:
	xor a
	Reader_ReadBitInline_B_DE
	rra
	Reader_ReadBitInline_B_DE
	rra
	Reader_ReadBitInline_B_DE
	rra
	Reader_ReadBitInline_B_DE
	rra
	Reader_ReadBitInline_B_DE
	rra
	Reader_ReadBitInline_B_DE
	rra
	Reader_ReadBitInline_B_DE
	rra
	rra
	ret

Reader_ReadBitsInline_8_DE:
	Reader_ReadBitInline_B_DE
	rra
	Reader_ReadBitInline_B_DE
	rra
	Reader_ReadBitInline_B_DE
	rra
	Reader_ReadBitInline_B_DE
	rra
	Reader_ReadBitInline_B_DE
	rra
	Reader_ReadBitInline_B_DE
	rra
	Reader_ReadBitInline_B_DE
	rra
	Reader_ReadBitInline_B_DE
	rra
	ret

Reader_Align:
	xor a
	ld (Reader_bits),a
	ret

;
Reader_endOfDataError:
	db "Premature end of data.",13,10,0
