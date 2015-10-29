;
; The dynamic alphabets
;
DynamicAlphabets_MAX_HEADERCODELENGTHS: equ 19
DynamicAlphabets_MAX_LITERALLENGTHCODELENGTHS: equ 286
DynamicAlphabets_MAX_DISTANCECODELENGTHS: equ 30

DynamicAlphabets: MACRO
	; TODO these are only used during the constructor, these should be
	;      local (or scratch) instead of member variables
	hlit:
		db 0  ; we only store the LSB, MSB is always 1
	hdist:
		db 0
	hclen:
		db 0
	headerCodeLengths:
		ds DynamicAlphabets_MAX_HEADERCODELENGTHS
	literalLengthDistanceCodeLengths:
		ds DynamicAlphabets_MAX_LITERALLENGTHCODELENGTHS + DynamicAlphabets_MAX_DISTANCECODELENGTHS
	_size:
	ENDM

DynamicAlphabets_class: Class DynamicAlphabets, DynamicAlphabets_template, Heap_main
DynamicAlphabets_template: DynamicAlphabets

; hl = literal/length symbol handlers table
; de = distance symbol handlers table
; ix = this
; iy = reader
; ix <- this
; de <- this
DynamicAlphabets_Construct:
	push de
	push hl
	call DynamicAlphabets_ReadLengths
	call DynamicAlphabets_ReadHeaderCodeLengths
	push iy
	call DynamicAlphabets_ConstructHeaderCodeAlphabet
	pop iy
	call DynamicAlphabets_ReadLiteralLengthDistanceCodeLengths
	pop hl
	call DynamicAlphabets_ConstructLiteralLengthAlphabet
	pop hl
	call DynamicAlphabets_ConstructDistanceAlphabet
	ld e,ixl
	ld d,ixh
	ret

; ix = this
DynamicAlphabets_ConstructHeaderCodeAlphabet:
	push ix

	ld bc,DynamicAlphabets_MAX_HEADERCODELENGTHS
	ld de,DynamicAlphabets.headerCodeLengths
	add ix,de
	ld e,ixl
	ld d,ixh	; de = length of symbols
	ld hl,HeaderCodeTree
	ld iy,DynamicAlphabets_headerCodeSymbols
	call generate_huffman

	pop ix
	ret

; hl = literal/length symbol handlers table
; ix = this
DynamicAlphabets_ConstructLiteralLengthAlphabet:
	push ix
	push hl

	ld c,(ix + DynamicAlphabets.hlit)
	ld b,1	; bc = number of symbols
	ld de,DynamicAlphabets.literalLengthDistanceCodeLengths
	add ix,de
	ld e,ixl
	ld d,ixh	; de = length of symbols
	ld hl,LiteralTree
	pop iy	; iy = literal/length symbol handlers table
	call generate_huffman

	pop ix
	ret


; hl = distance symbol handlers table
; ix = this
DynamicAlphabets_ConstructDistanceAlphabet:
	push ix
	push hl

	ld c,(ix + DynamicAlphabets.hdist)
	ld b,0	; bc = number of symbols
	ld e,(ix + DynamicAlphabets.hlit)
	ld d,1
	add ix,de
	ld de,DynamicAlphabets.literalLengthDistanceCodeLengths
	add ix,de
	ld e,ixl
	ld d,ixh	; de = length of symbols
	ld hl,DistanceTree
	pop iy	; iy = distance symbol handlers table
	call generate_huffman

	pop ix
	ret

; ix = this
; ix <- this
DynamicAlphabets_Destruct:
	ret

; ix = this
; iy = reader
DynamicAlphabets_ReadLengths:
	ld b,5
	call Reader_ReadBits_IY
	inc a
	cp (DynamicAlphabets_MAX_LITERALLENGTHCODELENGTHS & 0FFH) + 1
	call nc,System_ThrowException
	ld (ix + DynamicAlphabets.hlit),a
	ld b,5
	call Reader_ReadBits_IY
	inc a
	cp DynamicAlphabets_MAX_DISTANCECODELENGTHS + 1
	call nc,System_ThrowException
	ld (ix + DynamicAlphabets.hdist),a
	ld b,4
	call Reader_ReadBits_IY
	add a,4
	cp DynamicAlphabets_MAX_HEADERCODELENGTHS + 1
	call nc,System_ThrowException
	ld (ix + DynamicAlphabets.hclen),a
	ret

; ix = this
; iy = reader
DynamicAlphabets_ReadHeaderCodeLengths: PROC
	ld b,(ix + DynamicAlphabets.hclen)
	ld hl,DynamicAlphabets_headerCodeOrder
Loop:
	ld e,(hl)
	ld d,0
	inc hl
	push hl
	push ix
	add ix,de
	push bc
	ld b,3
	call Reader_ReadBits_IY
	pop bc
	ld (ix + DynamicAlphabets.headerCodeLengths),a
	pop ix
	pop hl
	djnz Loop
	ret
	ENDP

; ix = this
; iy = reader
DynamicAlphabets_ReadLiteralLengthDistanceCodeLengths:
	ld hl,DynamicAlphabets.literalLengthDistanceCodeLengths
	ld e,ixl
	ld d,ixh
	add hl,de
	ld a,(ix + DynamicAlphabets.hlit)
	add a,(ix + DynamicAlphabets.hdist)
	push ix
	ld e,a
	ld d,2  ; +1 for nested 8-bit loop
	push iy
	pop ix  ; ix = reader
	ld iy,HeaderCodeTree
	call Reader_PrepareReadBitInline
	call DynamicAlphabets_DecodeLiteralLengthDistanceCodeLengths
	call Reader_FinishReadBitInline
	pop ix
	ret

; c = inline bit reader state
; de = loop counter for nested 8-bit loop
; hl = literal/length/distance code lengths position
; ix = reader
; iy = header code alphabet root
DynamicAlphabets_DecodeLiteralLengthDistanceCodeLengths:
	jp iy

; c = inline bit reader state
; de = loop counter for nested 8-bit loop
; hl = literal/length/distance code lengths position
; ix = reader
; iy = header code alphabet root
DynamicAlphabets_WriteAndNext:
	inc hl
	dec e
	jp nz,DynamicAlphabets_DecodeLiteralLengthDistanceCodeLengths
	dec d
	jr nz,DynamicAlphabets_DecodeLiteralLengthDistanceCodeLengths
	ret

; a = fill value
; b = repeat count
; c = inline bit reader state
; de = loop counter for nested 8-bit loop
; hl = literal/length/distance code lengths position
; ix = reader
; iy = header code alphabet root
DynamicAlphabets_FillAndNext_Loop:
	dec b
	jr z,DynamicAlphabets_DecodeLiteralLengthDistanceCodeLengths
DynamicAlphabets_FillAndNext:
	ld (hl),a
	inc hl
	dec e
	jp nz,DynamicAlphabets_FillAndNext_Loop
	dec d
	jr nz,DynamicAlphabets_FillAndNext_Loop
	ret

; Header code alphabet symbols 0-15
; c = inline bit reader state
; de = loop counter for nested 8-bit loop
; hl = literal/length/distance code lengths position
; ix = reader
; iy = header code alphabet root
DynamicAlphabets_WriteLength: REPT 16, ?value
	ld (hl),?value
	jp DynamicAlphabets_WriteAndNext
	ENDM

; Header code alphabet symbols 16
; c = inline bit reader state
; de = loop counter for nested 8-bit loop
; hl = literal/length/distance code lengths position
; ix = reader
; iy = header code alphabet root
DynamicAlphabets_Copy:
	call Reader_ReadBitsInline_2
	add a,3
	ld b,a
	dec hl
	ld a,(hl)
	inc hl
	jp DynamicAlphabets_FillAndNext

; Header code alphabet symbols 17
; c = inline bit reader state
; de = loop counter for nested 8-bit loop
; hl = literal/length/distance code lengths position
; ix = reader
; iy = header code alphabet root
DynamicAlphabets_FillZero_3:
	call Reader_ReadBitsInline_3
	add a,3
	ld b,a
	xor a
	jp DynamicAlphabets_FillAndNext

; Header code alphabet symbols 18
; c = inline bit reader state
; de = loop counter for nested 8-bit loop
; hl = literal/length/distance code lengths position
; ix = reader
; iy = header code alphabet root
DynamicAlphabets_FillZero_11:
	call Reader_ReadBitsInline_7
	add a,11
	ld b,a
	xor a
	jp DynamicAlphabets_FillAndNext

;
DynamicAlphabets_headerCodeOrder:
	db 16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15

DynamicAlphabets_headerCodeSymbols:
	dw DynamicAlphabets_WriteLength.0, DynamicAlphabets_WriteLength.1, DynamicAlphabets_WriteLength.2, DynamicAlphabets_WriteLength.3
	dw DynamicAlphabets_WriteLength.4, DynamicAlphabets_WriteLength.5, DynamicAlphabets_WriteLength.6, DynamicAlphabets_WriteLength.7
	dw DynamicAlphabets_WriteLength.8, DynamicAlphabets_WriteLength.9, DynamicAlphabets_WriteLength.10, DynamicAlphabets_WriteLength.11
	dw DynamicAlphabets_WriteLength.12, DynamicAlphabets_WriteLength.13, DynamicAlphabets_WriteLength.14, DynamicAlphabets_WriteLength.15
	dw DynamicAlphabets_Copy, DynamicAlphabets_FillZero_3, DynamicAlphabets_FillZero_11, System_ThrowException


; scratch area: memory can be reused once DynamicAlphabets is created
HeaderCodeTree:
	ds 11 * (DynamicAlphabets_MAX_HEADERCODELENGTHS - 1)
