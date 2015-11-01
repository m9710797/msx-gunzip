;
; Memory buffer writer

Writer_count:
	dd 0
Writer_crc32:
	dd 0FFFFFFFFH
Writer_fileHandle:
	db 0FFH		; start with invalid file handle
Writer_bufPos:
	dw OBUFFER


; de = file path
Writer_Construct:
	ld a,d
	or e
	ret z
	ld a,00000010B  ; write only
	ld bc,0 * 256 + 44H ; _CREATE
	call #0005	; BDOS
	call Application_CheckDOSError
	ld a,b
	ld (Writer_fileHandle),a
	ret

Writer_Destruct:
	call Writer_FlushBuffer
	ld a,(Writer_fileHandle)
	ld b,a
	inc a
	ret z
	ld c,45H ; _CLOSE
	call #0005	; BDOS
	jp Application_CheckDOSError

; a = value
; hl = Writer_bufPos
Writer_Write_AndNext:
	ld (hl),a
	inc l
	jp nz,LiteralTree

	inc h
	ld a,h
	cp OBUFFER_END >> 8
	jp nz,LiteralTree
	ld (Writer_bufPos),hl	; OBUFFER_END
	call Writer_FinishBlock
	; hl = Writer_bufPos
	jp LiteralTree
	ENDP

; bc = byte count (range 3-258)
; de = distance - 1
; c' = inline bit reader state
; Modifies: af, bc, de, hl
; Remark: does not return, instead does 'exx ; jp LiteralTree'
Writer_Copy_AndNext: PROC
	pop hl   ; hl = Writer_bufPos
	push hl
	scf
	sbc hl,de
	pop de
	ld a,h
	jr c,Wrap
	cp OBUFFER >> 8
	jr c,Wrap
WrapContinue:
	ld a,OBUFFER_END_HIGH - 3
	cp h  ; does the source have a 512 byte margin without wrapping?
	jr c,Slow
	cp d  ; does the destination a 512 byte margin without wrapping?
	jr c,Slow
	ldi
	ldi
	ldir
	push de
	; and next
	exx
	pop hl	; updated Writer_bufPos
	jp LiteralTree

Wrap:	add a,OBUFFER_SIZE >> 8
	ld h,a
	jp WrapContinue

; bc = byte count
; hl = buffer source
; de = buffer destination
; Modifies: af, bc, de, hl
Slow:	ld (Writer_bufPos),de
	ld e,l
	ld d,h
	add hl,bc
	jr c,Split
	ld a,h
	cp OBUFFER_END >> 8
	jp c,WriteBlock_AndNext
; hl = end address
Split:
	push bc
	ld bc,OBUFFER_END
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
	ld hl,OBUFFER
	ld a,b
	or c
	jp nz,Slow
	; and next
	exx
	ld hl,(Writer_bufPos)
	jp LiteralTree

WriteBlock_AndNext:
	call WriteBlock
	; and next
	exx
	ld hl,(Writer_bufPos)
	jp LiteralTree

; bc = byte count
; de = source
; Modifies: af, bc, de, hl
WriteBlock:
	ld hl,(Writer_bufPos)
	add hl,bc
	jr c,Split2
	ld a,h
	cp OBUFFER_END >> 8
	jr nc,Split2
	and a
	sbc hl,bc
	ex de,hl
	ldir
	ld (Writer_bufPos),de
	ret
; hl = end address
Split2:
	push bc
	ld bc,OBUFFER_END
	and a
	sbc hl,bc  ; hl = bytes past end
	ld c,l
	ld b,h
	ex (sp),hl
	sbc hl,bc  ; hl = bytes until end
	ld c,l
	ld b,h
	ex de,hl
	ld de,(Writer_bufPos)
	ldir
	ld (Writer_bufPos),de
	push hl
	call Writer_FinishBlock
	pop de
	pop bc
	ld a,b
	or c
	jp nz,WriteBlock
	ret
	ENDP

; a = value
; de,bc <- unchanged
Writer_Write_slow:
	ld hl,(Writer_bufPos)
	ld (hl),a
	inc l
	ld a,l
	ld (Writer_bufPos),a
	ret nz
	inc h
	ld a,h
	ld (Writer_bufPos + 1),a
	cp OBUFFER_END >> 8
	ret nz
	;jp Writer_FinishBlock

Writer_FinishBlock: PROC
	push bc
	push de

	; Increase count
	; (Writer_count + 0) does not change
	ld hl,(Writer_count + 1)
	ld bc,OBUFFER_SIZE >> 8
	add hl,bc
	ld (Writer_count + 1),hl
	jr c,inc_16mb
inc_16mb_end:

	; Update CRC32
	exx
	push bc
	push hl
	ld hl,OBUFFER
	ld bc,OBUFFER_SIZE
	exx
	ld de,(Writer_crc32 + 0)
	ld bc,(Writer_crc32 + 2)
	call Writer_CalculateCRC32
	ld (Writer_crc32 + 0),de
	ld (Writer_crc32 + 2),bc
	exx
	pop hl
	pop bc
	exx

	call Writer_FlushBuffer
	pop de
	pop bc
	ld hl,OBUFFER
	ld (Writer_bufPos),hl
	ret

inc_16mb:
	ld hl,Writer_count + 3
	inc (hl)
	jr inc_16mb_end
	ENDP

; Modifies: af, bc, de, hl
Writer_FlushBuffer:
	ld c,0BH ; _CONST
	call #0005	; BDOS

	ld a,(Writer_fileHandle)
	ld b,a
	inc a
	ret z
	ld de,OBUFFER
	ld hl,(Writer_bufPos)
	and a
	sbc hl,de
	ld c,49H ; _WRITE
	call #0005	; BDOS
	jp Application_CheckDOSError

; Modifies: hl, bc

; dehl <- count bytes written
Writer_GetCount:
	ld hl,(Writer_bufPos)
	ld bc,OBUFFER
	and a
	sbc hl,bc
	ld bc,(Writer_count + 0)
	ld de,(Writer_count + 2)
	add hl,bc
	ret nc
	inc de
	ret

; bcde <- crc32
; Modifies: af, bc, de, hl
Writer_GetCRC32:
	exx
	push bc
	push hl
	ld hl,OBUFFER
	ld bc,(Writer_bufPos)
	ld a,b
	sub h
	ld b,a
	exx
	ld de,(Writer_crc32 + 0)
	ld bc,(Writer_crc32 + 2)
	call nz,Writer_CalculateCRC32
	exx
	pop hl
	pop bc
	exx
	ret

; bc' = byte count
; hl' = read address
; bcde = current crc
; bcde <- updated crc
; Modifies: af, bc, de, hl, bc', hl'
Writer_CalculateCRC32: PROC
	exx
	ld a,c  ; convert 16-bit counter bc to two 8-bit counters in b and c
	dec bc
	inc b
	ld c,b
	ld b,a
Loop:	ld a,(hl)
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
	djnz Loop
	dec c
	jp nz,Loop
	exx
	ret
	ENDP
