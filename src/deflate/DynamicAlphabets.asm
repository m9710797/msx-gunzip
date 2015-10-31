;
; The dynamic alphabets
;
DynamicAlphabets_MAX_HEADERCODELENGTHS: equ 19
DynamicAlphabets_MAX_LITERALLENGTHCODELENGTHS: equ 286
DynamicAlphabets_MAX_DISTANCECODELENGTHS: equ 30

; Strictly speaking we only need to store the LSB of the following two values.
; But also storing the MSB allows for simpler code, so the space overhead here
; is more than made up in smaller code size.
hlit:	dw 256	; MSB fixed at '1'
hdist:	dw 0	; MSB fixed at '0'

; Overlap 'headerCodeLengths' and 'literalLengthDistanceCodeLengths', they are
; not simultaneously life.
;   TODO Does 'glass' have a union feature?
; These are scratch buffers, they can be reused outside ConstructDynamicAlphabets
headerCodeLengths:
	; ds DynamicAlphabets_MAX_HEADERCODELENGTHS  ; the shorter of the two
literalLengthDistanceCodeLengths:
	ds DynamicAlphabets_MAX_LITERALLENGTHCODELENGTHS + DynamicAlphabets_MAX_DISTANCECODELENGTHS
HeaderCodeTree:
	ds 11 * (DynamicAlphabets_MAX_HEADERCODELENGTHS - 1)


ConstructDynamicAlphabets: PROC
	; Read hlit
	call Reader_PrepareReadBitInline
	call Reader_ReadBitsInline_5_DE
	inc a
	cp (DynamicAlphabets_MAX_LITERALLENGTHCODELENGTHS & 0FFH) + 1
	call nc,System_ThrowException
	ld (hlit),a

	; Read hdist
	call Reader_ReadBitsInline_5_DE
	inc a
	cp DynamicAlphabets_MAX_DISTANCECODELENGTHS + 1
	call nc,System_ThrowException
	ld (hdist),a

	; Read hclen
	call Reader_ReadBitsInline_4_DE
	add a,4
	cp DynamicAlphabets_MAX_HEADERCODELENGTHS + 1
	call nc,System_ThrowException

	; Clear header code lengths
	exx
	ld hl,headerCodeLengths
	ld de,headerCodeLengths + 1
	ld bc,DynamicAlphabets_MAX_HEADERCODELENGTHS - 1
	ld (hl),b ; 0
	ldir
	exx

	; Read header code lengths
	ld ixl,a	; hclen
	ld hl,DynamicAlphabets_headerCodeOrder
	ld iy,headerCodeLengths
Loop:	ld a,(hl)
	inc hl
	ld (Store + 2),a ; self modifying code!
	call Reader_ReadBitsInline_3_DE ; changes B
Store:	ld (iy + 0),a  ; offset is dynamically changed!
	dec ixl
	jr nz,Loop
	push bc
	push de

	; Construct header code alphabet
	ld bc,DynamicAlphabets_MAX_HEADERCODELENGTHS
	ld de,headerCodeLengths ; de = length of symbols
	ld hl,HeaderCodeTree
	push hl
	ld iy,DynamicAlphabets_headerCodeSymbols
	call generate_huffman

	; Read literal length distance code lengths
	ld bc,(hdist)
	ld ix,(hlit)
	add ix,bc
	inc ixh	; +1 for nested 8-bit loop
	pop iy	; iy = HeaderCodeTree
	ld hl,literalLengthDistanceCodeLengths
	pop de
	pop bc
	call DynamicAlphabets_DecodeLiteralLengthDistanceCodeLengths
	call Reader_FinishReadBitInline

	; Construct literal length alphabet
	ld bc,(hlit) ; bc = number of symbols
	ld de,literalLengthDistanceCodeLengths ; de = length of symbols
	ld hl,LiteralTree
	ld iy,Inflate_literalLengthSymbols	; iy = literal/length symbol handlers table
	call generate_huffman

	; Construct distance alphabet
	ld bc,(hdist) ; bc = number of symbols
	ld hl,literalLengthDistanceCodeLengths
	ld de,(hlit)
	add hl,de
	ex de,hl	; de = length of symbols
	ld hl,DistanceTree
	ld iy,Inflate_distanceSymbols	; iy = distance symbol handlers table
	jp generate_huffman

	ENDP


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
	dec ixl
	jp nz,DynamicAlphabets_DecodeLiteralLengthDistanceCodeLengths
	dec ixh
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
	dec ixl
	jp nz,DynamicAlphabets_FillAndNext_Loop
	dec ixh
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
	call Reader_ReadBitsInline_2_DE
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
	call Reader_ReadBitsInline_3_DE
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
	call Reader_ReadBitsInline_7_DE
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
