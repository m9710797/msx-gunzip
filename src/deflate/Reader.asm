;
; Memory buffer reader
;

;----
ReaderObject: equ $
; ix = this
; a <- value
	ld a,(0)
Reader_bufPos: equ $ - 2
	inc (ix + Reader_bufPosOfst)
	ret nz
	jp Reader_Read.Continue

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
	call DOS_OpenFileHandle
	call Application_CheckDOSError
	ld a,b
	ld (Reader_fileHandle),a
	call Reader_FillBuffer
	ret

Reader_Destruct:
	ld a,(Reader_fileHandle)
	ld b,a
	call DOS_CloseFileHandle
	jp Application_CheckDOSError

; ix = this
; a <- value
; Modifies: none
Reader_Read: PROC
	jp ix
Continue:
	push af
	ld a,(Reader_bufPos + 1)
	inc a
	cp IBUFFER_END >> 8
	call z,NextBlock
	ld (Reader_bufPos + 1),a
	pop af
	ret
NextBlock:
	push bc
	push de
	push hl
	ld a,(Reader_endOfData)
	or a
	ld hl,Reader_endOfDataError
	call nz,System_ThrowExceptionWithMessage
	call Reader_FillBuffer
	pop hl
	pop de
	pop bc
	ld a,(Reader_endOfData)
	or a
	ld a,IBUFFER >> 8	; bufferStart
	ret z
TrapNextRead:
	ld a,0FFH
	ld (Reader_bufPos),a
	ld a,IBUFFER_END_HIGH - 1
	ret
	ENDP

; Modifies: af, bc, de, hl
Reader_FillBuffer: PROC
	call DOS_ConsoleStatus  ; allow ctrl-c
	ld a,(Reader_fileHandle)
	ld b,a
	ld de,IBUFFER
	ld hl,IBUFFER_SIZE
	call DOS_ReadFromFileHandle
	cp .EOF
	jp nz,Application_CheckDOSError
	;jp Reader_MarkEndOfData
	ENDP

Reader_MarkEndOfData:
	ld a,1
	ld (Reader_endOfData),a
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
	srl (ix + Reader_bitsOfst)
	ret nz  ; return if sentinel bit is still present
	push bc
	ld c,a
	call Reader_Read
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
	xor a
	ld (Reader_bits),a
	ret

;
Reader_endOfDataError:
	db "Premature end of data.",13,10,0
