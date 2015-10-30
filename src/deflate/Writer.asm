;
; Memory buffer writer
;
Writer: MACRO
	; a = value
	; iy = this
	Write_IY:
		ld (0),a
	bufferPosition: equ $ - 2
		inc (iy + Writer.bufferPosition)
		ret nz
		jp Writer_Write_IY.Continue

	count:
		dd 0
	crc32:
		dd 0FFFFFFFFH
	fileHandle:
		db 0FFH
	_size:
	ENDM

Writer_class: Class Writer, Writer_template, Heap_main
Writer_template: Writer

; de = file path
; ix = this
; ix <- this
; de <- this
Writer_Construct:
	ld a,l  ; check if buffer is 256-byte aligned
	or c
	call nz,System_ThrowException
	ld hl,OBUFFER
	ld (ix + Writer.bufferPosition),l
	ld (ix + Writer.bufferPosition + 1),h

	ld (ix + Writer.fileHandle),0FFH	; invalid file handle
	ld a,d
	or e
	jr z,no_file
	ld a,00000010B  ; write only
	ld b,0
	call DOS_CreateFileHandle
	call Application_CheckDOSError
	ld (ix + Writer.fileHandle),b
no_file:
	ld e,ixl
	ld d,ixh
	ret

; ix = this
; ix <- this
Writer_Destruct:
	call Writer_FlushBuffer
	ld b,(ix + Writer.fileHandle)
	ld a,b
	inc a
	ret z
	call DOS_CloseFileHandle
	jp Application_CheckDOSError

; a = value
; iy = this
; Modifies: none
Writer_Write_IY: PROC
	jp iy
Continue:
	push af
	ld a,(iy + Writer.bufferPosition + 1)
	inc a
	cp OBUFFER_END >> 8
	call z,NextBlock
	ld (iy + Writer.bufferPosition + 1),a
	pop af
	ret
NextBlock:
	ld (iy + Writer.bufferPosition + 1),a
	push hl
	call Writer_FinishBlock_IY
	pop hl
	ld a,(iy + Writer.bufferPosition + 1)
	ret
	ENDP

; bc = byte count (range 3-258)
; de = distance - 1
; iy = this
; Modifies: af, bc, de, hl
Writer_Copy_IY: PROC
	ld l,(iy + Writer.bufferPosition)
	ld h,(iy + Writer.bufferPosition + 1)
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
	jr c,Writer_Copy_Slow_IY
	cp d  ; does the destination a 512 byte margin without wrapping?
	jr c,Writer_Copy_Slow_IY
	ldi
	ldi
	ldir
	ld (iy + Writer.bufferPosition),e
	ld (iy + Writer.bufferPosition + 1),d
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
Writer_Copy_Slow_IY: PROC
	ld e,l
	ld d,h
	add hl,bc
	jr c,Split
	ld a,h
	cp OBUFFER_END >> 8
	jp c,Writer_WriteBlock_IY
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
	call Writer_WriteBlock_IY
	pop bc
	ld hl,OBUFFER
	ld a,b
	or c
	jp nz,Writer_Copy_Slow_IY
	ret
	ENDP

; bc = byte count
; de = source
; iy = this
; Modifies: af, bc, de, hl
Writer_WriteBlock_IY: PROC
	ld l,(iy + Writer.bufferPosition)
	ld h,(iy + Writer.bufferPosition + 1)
	add hl,bc
	jr c,Split
	ld a,h
	cp OBUFFER_END >> 8
	jr nc,Split
	and a
	sbc hl,bc
	ex de,hl
	ldir
	ld (iy + Writer.bufferPosition),e
	ld (iy + Writer.bufferPosition + 1),d
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
	ld e,(iy + Writer.bufferPosition)
	ld d,(iy + Writer.bufferPosition + 1)
	ldir
	ld (iy + Writer.bufferPosition),e
	ld (iy + Writer.bufferPosition + 1),d
	push hl
	call Writer_FinishBlock_IY
	pop de
	pop bc
	ld a,b
	or c
	jp nz,Writer_WriteBlock_IY
	ret
	ENDP

; ix = this
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
	ld (ix + Writer.bufferPosition),l
	ld (ix + Writer.bufferPosition + 1),h
	ret

; iy = this
; hl <- buffer position
; Modifies: af
Writer_FinishBlock_IY:
	push iy
	ex (sp),ix
	call Writer_FinishBlock
	pop ix
	ret

; ix = this
; Modifies: af, bc, de, hl
Writer_FlushBuffer:
	call DOS_ConsoleStatus  ; allow ctrl-c
	ld b,(ix + Writer.fileHandle)
	ld a,b
	inc a
	ret z
	ld de,OBUFFER
	ld l,(ix + Writer.bufferPosition)
	ld h,(ix + Writer.bufferPosition + 1)
	and a
	sbc hl,de
	call DOS_WriteToFileHandle
	jp Application_CheckDOSError

; ix = this
; Modifies: hl, bc
Writer_IncreaseCount:
	ld l,(ix + Writer.count)
	ld h,(ix + Writer.count + 1)
	ld bc,OBUFFER_SIZE
	add hl,bc
	ld (ix + Writer.count),l
	ld (ix + Writer.count + 1),h
	ret nc
	inc (ix + Writer.count + 2)
	ret nz
	inc (ix + Writer.count + 3)
	ret

; ix = this
; dehl <- count bytes written
Writer_GetCount:
	ld l,(ix + Writer.bufferPosition)
	ld h,(ix + Writer.bufferPosition + 1)
	ld bc,OBUFFER
	and a
	sbc hl,bc
	call c,System_ThrowException
	ld c,(ix + Writer.count)
	ld b,(ix + Writer.count + 1)
	ld e,(ix + Writer.count + 2)
	ld d,(ix + Writer.count + 3)
	add hl,bc
	ret nc
	inc de
	ret

; a = value
; ix = this
; Modifies: af, bc, de, hl
Writer_UpdateCRC32:
	exx
	push bc
	push hl
	ld hl,OBUFFER
	ld bc,OBUFFER_SIZE
	exx
	ld e,(ix + Writer.crc32)
	ld d,(ix + Writer.crc32 + 1)
	ld c,(ix + Writer.crc32 + 2)
	ld b,(ix + Writer.crc32 + 3)
	call Writer_CalculateCRC32
	ld (ix + Writer.crc32),e
	ld (ix + Writer.crc32 + 1),d
	ld (ix + Writer.crc32 + 2),c
	ld (ix + Writer.crc32 + 3),b
	exx
	pop hl
	pop bc
	exx
	ret

; ix = this
; bcde <- crc32
; Modifies: af, bc, de, hl
Writer_GetCRC32:
	exx
	push bc
	push hl
	ld l,(ix + Writer.bufferPosition)
	ld h,(ix + Writer.bufferPosition + 1)
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
	ld e,(ix + Writer.crc32)
	ld d,(ix + Writer.crc32 + 1)
	ld c,(ix + Writer.crc32 + 2)
	ld b,(ix + Writer.crc32 + 3)
	call nz,Writer_CalculateCRC32
	exx
	pop hl
	pop bc
	exx
	ret

; bc' = byte count
; hl' = read address
; bcde = current crc
; ix = this
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
