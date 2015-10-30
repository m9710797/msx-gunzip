;
; Memory buffer reader
;

;----
ReaderObject: equ $
; ix = this
; a <- value
	ld a,(IBUFFER)
Reader_bufPos: equ $ - 2
	inc (ix + Reader_bufPosOfst)
	ret nz
	jp Reader_Read_IX.Continue

Reader_bits:
	db 0

Reader_bufPosOfst:    equ Reader_bufPos - ReaderObject
Reader_bitsOfst:      equ Reader_bits   - ReaderObject
;----

Reader_endOfData:
	db 0
Reader_fileHandle:
	db 0FFH


; de = file path
Reader_Construct:
	ld hl,IBUFFER
	ld (Reader_bufPos),hl

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

; ix = this
; a <- value
; Modifies: none
Reader_Read_IX: PROC
	jp ix
Continue:
	push af
	ld a,(Reader_bufPos + 1)
	inc a
	cp IBUFFER_END >> 8
	jr z,NextBlock
End:	ld (Reader_bufPos + 1),a
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
	ld a,IBUFFER >> 8	; bufferStart
	jr z,End
	; trap next read
	ld a,0FFH
	ld (Reader_bufPos),a
	ld a,IBUFFER_END_HIGH - 1
	jr End
EofError:
	ld hl,Reader_endOfDataError
	call System_ThrowExceptionWithMessage
	ENDP

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

; bc = nr of bytes to skip
; ix = this
; Modifies: bc, a
Reader_Skip_IX:
	call Reader_Read_IX
	dec bc
	ld a,b
	or c
	jr nz,Reader_Skip_IX
	ret

; ix = this
; f <- c: bit
; Modifies: none
Reader_ReadBit_IX:
	srl (ix + Reader_bitsOfst)
	ret nz  ; return if sentinel bit is still present
	push bc
	ld c,a
	call Reader_Read_IX
	scf  ; set sentinel bit
	rra
	ld (Reader_bits),a
	ld a,c
	pop bc
	ret

; c <- inline bit reader state
Reader_PrepareReadBitInline:
	ld a,(Reader_bits)
	ld c,a
	ret

; c = inline bit reader state
Reader_FinishReadBitInline:
	ld a,c
	ld (Reader_bits),a
	ret

; c = inline bit reader state
; c <- inline bit reader state
; f <- c: bit
; Modifies: a
Reader_ReadBitInline_IX: MACRO
	srl c
	call z,Reader_ReadBitInline_NextByte_IX  ; if sentinel bit is shifted out
	ENDM

; c <- inline bit reader state
; f <- c: bit
; Modifies: a
Reader_ReadBitInline_NextByte_IX:
	call Reader_Read_IX
	scf  ; set sentinel bit
	rra
	ld c,a
	ret

; c = inline bit reader state
; c <- inline bit reader state
; f <- c: bit
; Modifies: b
Reader_ReadBitInline_B_IX: MACRO
	srl c
	call z,Reader_ReadBitInline_B_NextByte_IX  ; if sentinel bit is shifted out
	ENDM

; c <- inline bit reader state
; f <- c: bit
; Modifies: b
Reader_ReadBitInline_B_NextByte_IX:
	ld b,a
	call Reader_Read_IX
	scf  ; set sentinel bit
	rra
	ld c,a
	ld a,b
	ret

; c = inline bit reader state
; a <- value
; c <- inline bit reader state
; Modifies: b
Reader_ReadBitsInline_1_IX:
	xor a
	Reader_ReadBitInline_B_IX
	rla
	ret

Reader_ReadBitsInline_2_IX:
	xor a
	Reader_ReadBitInline_B_IX
	rra
	Reader_ReadBitInline_B_IX
	rla
	rla
	ret

Reader_ReadBitsInline_3_IX:
	xor a
	Reader_ReadBitInline_B_IX
	rra
	Reader_ReadBitInline_B_IX
	rra
	Reader_ReadBitInline_B_IX
	rla
	rla
	rla
	ret

Reader_ReadBitsInline_4_IX:
	xor a
	Reader_ReadBitInline_B_IX
	rra
	Reader_ReadBitInline_B_IX
	rra
	Reader_ReadBitInline_B_IX
	rra
	Reader_ReadBitInline_B_IX
	rla
	rla
	rla
	rla
	ret

Reader_ReadBitsInline_5_IX:
	xor a
	Reader_ReadBitInline_B_IX
	rra
	Reader_ReadBitInline_B_IX
	rra
	Reader_ReadBitInline_B_IX
	rra
	Reader_ReadBitInline_B_IX
	rra
	Reader_ReadBitInline_B_IX
	rra
	rra
	rra
	rra
	ret

Reader_ReadBitsInline_6_IX:
	xor a
	Reader_ReadBitInline_B_IX
	rra
	Reader_ReadBitInline_B_IX
	rra
	Reader_ReadBitInline_B_IX
	rra
	Reader_ReadBitInline_B_IX
	rra
	Reader_ReadBitInline_B_IX
	rra
	Reader_ReadBitInline_B_IX
	rra
	rra
	rra
	ret

Reader_ReadBitsInline_7_IX:
	xor a
	Reader_ReadBitInline_B_IX
	rra
	Reader_ReadBitInline_B_IX
	rra
	Reader_ReadBitInline_B_IX
	rra
	Reader_ReadBitInline_B_IX
	rra
	Reader_ReadBitInline_B_IX
	rra
	Reader_ReadBitInline_B_IX
	rra
	Reader_ReadBitInline_B_IX
	rra
	rra
	ret

Reader_ReadBitsInline_8_IX:
	Reader_ReadBitInline_B_IX
	rra
	Reader_ReadBitInline_B_IX
	rra
	Reader_ReadBitInline_B_IX
	rra
	Reader_ReadBitInline_B_IX
	rra
	Reader_ReadBitInline_B_IX
	rra
	Reader_ReadBitInline_B_IX
	rra
	Reader_ReadBitInline_B_IX
	rra
	Reader_ReadBitInline_B_IX
	rra
	ret

; b = nr of bits to read (1-8)
; ix = this
; a <- value
; Modifies: af, bc
Reader_ReadBits_IX: PROC
	ld c,1
	xor a
Loop:	call Reader_ReadBit_IX
	jr nc,Zero
	add a,c
Zero:	rlc c
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
	call Reader_ReadBits_IX
	pop ix
	ret

; ix = this
Reader_Align:
	xor a
	ld (Reader_bits),a
	ret

;
Reader_endOfDataError:
	db "Premature end of data.",13,10,0
