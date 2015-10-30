;
; Memory buffer writer

WriterObject:
; a = value
; iy = this
	ld (0),a
Writer_bufPos: equ $ - 2
	inc (iy + Writer_bufPosOfst)
	ret nz
	jp Writer_Write_IY.Continue

Writer_bufPosOfst: equ Writer_bufPos - WriterObject


Writer_count:
	dd 0
Writer_crc32:
	dd 0FFFFFFFFH
Writer_fileHandle:
	db 0FFH		; start with invalid file handle


; de = file path
Writer_Construct:
	ld a,l  ; check if buffer is 256-byte aligned
	or c
	call nz,System_ThrowException
	ld hl,OBUFFER
	ld (Writer_bufPos),hl

	ld a,d
	or e
	ret z
	ld a,00000010B  ; write only
	ld bc,0 * 256 + 44H ; _CREATE
	call BDOS

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
	call BDOS
	jp Application_CheckDOSError

; a = value
; iy = this
; Modifies: none
Writer_Write_IY: PROC
	jp iy
Continue:
	push af
	ld a,(Writer_bufPos + 1)
	inc a
	cp OBUFFER_END >> 8
	call z,NextBlock
	ld (Writer_bufPos + 1),a
	pop af
	ret
NextBlock:
	ld (Writer_bufPos + 1),a
	push hl
	call Writer_FinishBlock
	pop hl
	ld a,(Writer_bufPos + 1)
	ret
	ENDP

; bc = byte count (range 3-258)
; de = distance - 1
; iy = this
; Modifies: af, bc, de, hl
Writer_Copy: PROC
	ld hl,(Writer_bufPos)
	push hl
	scf
	sbc hl,de
	ld a,h
	jr c,Wrap
	cp OBUFFER >> 8
	jr c,Wrap
WrapContinue:
	pop de
	ld a,OBUFFER_END_HIGH - 3
	cp h  ; does the source have a 512 byte margin without wrapping?
	jr c,Writer_Copy_Slow
	cp d  ; does the destination a 512 byte margin without wrapping?
	jr c,Writer_Copy_Slow
	ldi
	ldi
	ldir
	ld (Writer_bufPos),de
	ret
Wrap:
	add a,OBUFFER_SIZE >> 8
	ld h,a
	jp WrapContinue
	ENDP

; bc = byte count
; hl = buffer source
; de = buffer destination
; iy = this
; Modifies: af, bc, de, hl
Writer_Copy_Slow: PROC
	ld e,l
	ld d,h
	add hl,bc
	jr c,Split
	ld a,h
	cp OBUFFER_END >> 8
	jp c,Writer_WriteBlock
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
	call Writer_WriteBlock
	pop bc
	ld hl,OBUFFER
	ld a,b
	or c
	jp nz,Writer_Copy_Slow
	ret
	ENDP

; bc = byte count
; de = source
; iy = this
; Modifies: af, bc, de, hl
Writer_WriteBlock: PROC
	ld hl,(Writer_bufPos)
	add hl,bc
	jr c,Split
	ld a,h
	cp OBUFFER_END >> 8
	jr nc,Split
	and a
	sbc hl,bc
	ex de,hl
	ldir
	ld (Writer_bufPos),de
	ret
; hl = end address
Split:
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
	jp nz,Writer_WriteBlock
	ret
	ENDP

; hl <- buffer position
; Modifies: af
Writer_FinishBlock:
	push bc
	push de
	call Writer_IncreaseCount
	call Writer_UpdateCRC32
	call Writer_FlushBuffer
	pop de
	pop bc
	ld hl,OBUFFER
	ld (Writer_bufPos),hl
	ret

; Modifies: af, bc, de, hl
Writer_FlushBuffer:
	ld c,0BH ; _CONST
	call BDOS

	ld a,(Writer_fileHandle)
	ld b,a
	inc a
	ret z
	ld de,OBUFFER
	ld hl,(Writer_bufPos)
	and a
	sbc hl,de
	ld c,49H ; _WRITE
	call BDOS
	jp Application_CheckDOSError

; Modifies: hl, bc
Writer_IncreaseCount:
	ld hl,(Writer_count + 0)
	ld bc,OBUFFER_SIZE
	add hl,bc
	ld (Writer_count + 0),hl
	ret nc
	ld hl,(Writer_count + 2)
	inc hl
	ld (Writer_count + 2),hl
	ret

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

; a = value
; Modifies: af, bc, de, hl
Writer_UpdateCRC32:
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
	ret

; bcde <- crc32
; Modifies: af, bc, de, hl
Writer_GetCRC32:
	exx
	push bc
	push hl
	ld hl,(Writer_bufPos)
	ld bc,OBUFFER
	and a
	sbc hl,bc
	call c,System_ThrowException
	ld a,l
	ld l,c
	ld c,a
	ld a,h
	ld h,b
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
Loop:
	ld a,(hl)
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
