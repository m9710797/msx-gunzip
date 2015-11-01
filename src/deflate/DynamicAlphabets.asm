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
	ds (8+5) * (DynamicAlphabets_MAX_HEADERCODELENGTHS - 1)
HeaderCodeTreeEnd: equ $


ConstructDynamicAlphabets: PROC
	; Read hlit
	call Reader_PrepareReadBitInline
	call Reader_ReadBitsInline_5_DE
	inc a
	cp (DynamicAlphabets_MAX_LITERALLENGTHCODELENGTHS & 0FFH) + 1
	call nc,ThrowException
	ld (hlit),a

	; Read hdist
	call Reader_ReadBitsInline_5_DE
	inc a
	cp DynamicAlphabets_MAX_DISTANCECODELENGTHS + 1
	call nc,ThrowException
	ld (hdist),a

	; Read hclen
	call Reader_ReadBitsInline_4_DE
	add a,4
	cp DynamicAlphabets_MAX_HEADERCODELENGTHS + 1
	call nc,ThrowException

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
	ld hl,HeaderCodeTreeEnd
	ld de,(out_ptr)
	or a
	sbc hl,de
	call c,ThrowException

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
	ld hl,LiteralTreeEnd
	ld de,(out_ptr)
	or a
	sbc hl,de
	call c,ThrowException

	; Construct distance alphabet
	ld bc,(hdist) ; bc = number of symbols
	ld hl,literalLengthDistanceCodeLengths
	ld de,(hlit)
	add hl,de
	ex de,hl	; de = length of symbols
	ld hl,DistanceTree
	ld iy,Inflate_distanceSymbols	; iy = distance symbol handlers table
	call generate_huffman
	ld hl,DistanceTreeEnd
	ld de,(out_ptr)
	or a
	sbc hl,de
	call c,ThrowException
	ret

	ENDP


; c = inline bit reader state
; de = inline Reader_bufPos
; hl = literal/length/distance code lengths position
; ix = loop counter for nested 8-bit loop
; iy = header code alphabet root
DynamicAlphabets_DecodeLiteralLengthDistanceCodeLengths:
	jp iy

; c = inline bit reader state
; de = inline Reader_bufPos
; hl = literal/length/distance code lengths position
; ix = loop counter for nested 8-bit loop
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
; de = inline Reader_bufPos
; hl = literal/length/distance code lengths position
; ix = loop counter for nested 8-bit loop
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
; de = inline Reader_bufPos
; hl = literal/length/distance code lengths position
; ix = loop counter for nested 8-bit loop
; iy = header code alphabet root
WriteLen_0:	ld (hl),0
		jp DynamicAlphabets_WriteAndNext
WriteLen_0_len: equ $-WriteLen_0

WriteLen_1:	ld (hl),1
		jp DynamicAlphabets_WriteAndNext
WriteLen_1_len: equ $-WriteLen_1

WriteLen_2:	ld (hl),2
		jp DynamicAlphabets_WriteAndNext
WriteLen_2_len: equ $-WriteLen_2

WriteLen_3:	ld (hl),3
		jp DynamicAlphabets_WriteAndNext
WriteLen_3_len: equ $-WriteLen_3

WriteLen_4:	ld (hl),4
		jp DynamicAlphabets_WriteAndNext
WriteLen_4_len: equ $-WriteLen_4

WriteLen_5:	ld (hl),5
		jp DynamicAlphabets_WriteAndNext
WriteLen_5_len: equ $-WriteLen_5

WriteLen_6:	ld (hl),6
		jp DynamicAlphabets_WriteAndNext
WriteLen_6_len: equ $-WriteLen_6

WriteLen_7:	ld (hl),7
		jp DynamicAlphabets_WriteAndNext
WriteLen_7_len: equ $-WriteLen_7

WriteLen_8:	ld (hl),8
		jp DynamicAlphabets_WriteAndNext
WriteLen_8_len: equ $-WriteLen_8

WriteLen_9:	ld (hl),9
		jp DynamicAlphabets_WriteAndNext
WriteLen_9_len: equ $-WriteLen_9

WriteLen_10:	ld (hl),10
		jp DynamicAlphabets_WriteAndNext
WriteLen_10_len: equ $-WriteLen_10

WriteLen_11:	ld (hl),11
		jp DynamicAlphabets_WriteAndNext
WriteLen_11_len: equ $-WriteLen_11

WriteLen_12:	ld (hl),12
		jp DynamicAlphabets_WriteAndNext
WriteLen_12_len: equ $-WriteLen_12

WriteLen_13:	ld (hl),13
		jp DynamicAlphabets_WriteAndNext
WriteLen_13_len: equ $-WriteLen_13

WriteLen_14:	ld (hl),14
		jp DynamicAlphabets_WriteAndNext
WriteLen_14_len: equ $-WriteLen_14

WriteLen_15:	ld (hl),15
		jp DynamicAlphabets_WriteAndNext
WriteLen_15_len: equ $-WriteLen_15

; Header code alphabet symbols 16
; c = inline bit reader state
; de = inline Reader_bufPos
; hl = literal/length/distance code lengths position
; ix = loop counter for nested 8-bit loop
; iy = header code alphabet root
DynamicAlphabets_Copy:
	call Reader_ReadBitsInline_2_DE
	add a,3
	ld b,a
	dec hl
	ld a,(hl)
	inc hl
	jp DynamicAlphabets_FillAndNext
DynamicAlphabets_Copy_len: equ $ - DynamicAlphabets_Copy

; Header code alphabet symbols 17
; c = inline bit reader state
; de = inline Reader_bufPos
; hl = literal/length/distance code lengths position
; ix = loop counter for nested 8-bit loop
; iy = header code alphabet root
DynamicAlphabets_FillZero_3:
	call Reader_ReadBitsInline_3_DE
	add a,3
	ld b,a
	xor a
	jp DynamicAlphabets_FillAndNext
DynamicAlphabets_FillZero_3_len: equ $-DynamicAlphabets_FillZero_3

; Header code alphabet symbols 18
; c = inline bit reader state
; de = inline Reader_bufPos
; hl = literal/length/distance code lengths position
; ix = loop counter for nested 8-bit loop
; iy = header code alphabet root
DynamicAlphabets_FillZero_11:
	call Reader_ReadBitsInline_7_DE
	add a,11
	ld b,a
	xor a
	jp DynamicAlphabets_FillAndNext
DynamicAlphabets_FillZero_11_len: equ $ - DynamicAlphabets_FillZero_11

;
DynamicAlphabets_headerCodeOrder:
	db 16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15

DynamicAlphabets_headerCodeSymbols:
	db WriteLen_0_len
	dw WriteLen_0
	db WriteLen_1_len
	dw WriteLen_1
	db WriteLen_2_len
	dw WriteLen_2
	db WriteLen_3_len
	dw WriteLen_3
	db WriteLen_4_len
	dw WriteLen_4
	db WriteLen_5_len
	dw WriteLen_5
	db WriteLen_6_len
	dw WriteLen_6
	db WriteLen_7_len
	dw WriteLen_7
	db WriteLen_8_len
	dw WriteLen_8
	db WriteLen_9_len
	dw WriteLen_9
	db WriteLen_10_len
	dw WriteLen_10
	db WriteLen_11_len
	dw WriteLen_11
	db WriteLen_12_len
	dw WriteLen_12
	db WriteLen_13_len
	dw WriteLen_13
	db WriteLen_14_len
	dw WriteLen_14
	db WriteLen_15_len
	dw WriteLen_15

	db DynamicAlphabets_Copy_len
	dw DynamicAlphabets_Copy
	db DynamicAlphabets_FillZero_3_len
	dw DynamicAlphabets_FillZero_3
	db DynamicAlphabets_FillZero_11_len
	dw DynamicAlphabets_FillZero_11
	db System_ThrowException_len
	dw System_ThrowException_
