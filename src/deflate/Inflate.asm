; Distance alphabet symbols 0-29
; c = inline bit reader state
; bc = length
; de = inline Reader_bufPos
; iy = Writer_Write_AndNext
Inflate_CopyDistance_0:
	push hl
	exx
	ld de,1 - 1
	jp Writer_Copy_AndNext
Inflate_CopyDistance_0_len: equ $ - Inflate_CopyDistance_0

Inflate_CopyDistance_1:
	push hl
	exx
	ld de,2 - 1
	jp Writer_Copy_AndNext
Inflate_CopyDistance_1_len: equ $ - Inflate_CopyDistance_1

Inflate_CopyDistance_2:
	push hl
	exx
	ld de,3 - 1
	jp Writer_Copy_AndNext
Inflate_CopyDistance_2_len: equ $ - Inflate_CopyDistance_2

Inflate_CopyDistance_3:
	push hl
	exx
	ld de,4 - 1
	jp Writer_Copy_AndNext
Inflate_CopyDistance_3_len: equ $ - Inflate_CopyDistance_3

Inflate_CopyDistance_4:
	call Reader_ReadBitsInline_1_DE
	add a,5 - 1
	jp Inflate_CopyAndNext_SetSmallDistance
Inflate_CopyDistance_4_len: equ $ - Inflate_CopyDistance_4

Inflate_CopyDistance_5:
	call Reader_ReadBitsInline_1_DE
	add a,7 - 1
	jp Inflate_CopyAndNext_SetSmallDistance
Inflate_CopyDistance_5_len: equ $ - Inflate_CopyDistance_5

Inflate_CopyDistance_6:
	call Reader_ReadBitsInline_2_DE
	add a,9 - 1
	jp Inflate_CopyAndNext_SetSmallDistance
Inflate_CopyDistance_6_len: equ $ - Inflate_CopyDistance_6

Inflate_CopyDistance_7:
	call Reader_ReadBitsInline_2_DE
	add a,13 - 1
	jp Inflate_CopyAndNext_SetSmallDistance
Inflate_CopyDistance_7_len: equ $ - Inflate_CopyDistance_7

Inflate_CopyDistance_8:
	call Reader_ReadBitsInline_3_DE
	add a,17 - 1
	jp Inflate_CopyAndNext_SetSmallDistance
Inflate_CopyDistance_8_len: equ $ - Inflate_CopyDistance_8

Inflate_CopyDistance_9:
	call Reader_ReadBitsInline_3_DE
	add a,25 - 1
	jp Inflate_CopyAndNext_SetSmallDistance
Inflate_CopyDistance_9_len: equ $ - Inflate_CopyDistance_9

Inflate_CopyDistance_10:
	call Reader_ReadBitsInline_4_DE
	add a,33 - 1
	jp Inflate_CopyAndNext_SetSmallDistance
Inflate_CopyDistance_10_len: equ $ - Inflate_CopyDistance_10

Inflate_CopyDistance_11:
	call Reader_ReadBitsInline_4_DE
	add a,49 - 1
	jp Inflate_CopyAndNext_SetSmallDistance
Inflate_CopyDistance_11_len: equ $ - Inflate_CopyDistance_11

Inflate_CopyDistance_12:
	call Reader_ReadBitsInline_5_DE
	add a,65 - 1
	jp Inflate_CopyAndNext_SetSmallDistance
Inflate_CopyDistance_12_len: equ $ - Inflate_CopyDistance_12

Inflate_CopyDistance_13:
	call Reader_ReadBitsInline_5_DE
	add a,97 - 1
	jp Inflate_CopyAndNext_SetSmallDistance
Inflate_CopyDistance_13_len: equ $ - Inflate_CopyDistance_13

Inflate_CopyDistance_14:
	call Reader_ReadBitsInline_6_DE
	add a,129 - 1
	jp Inflate_CopyAndNext_SetSmallDistance
Inflate_CopyDistance_14_len: equ $ - Inflate_CopyDistance_14

Inflate_CopyDistance_15:
	call Reader_ReadBitsInline_6_DE
	add a,193 - 1
	jp Inflate_CopyAndNext_SetSmallDistance
Inflate_CopyDistance_15_len: equ $ - Inflate_CopyDistance_15

Inflate_CopyDistance_16:
	call Reader_ReadBitsInline_7_DE
	push hl
	exx
	ld e,a
	ld d,257 - 1 >> 8
	jp Writer_Copy_AndNext
Inflate_CopyDistance_16_len: equ $ - Inflate_CopyDistance_16

Inflate_CopyDistance_17:
	call Reader_ReadBitsInline_7_DE
	push hl
	exx
	add a,385 - 1 & 0FFH
	ld e,a
	ld d,385 - 1 >> 8
	jp Writer_Copy_AndNext
Inflate_CopyDistance_17_len: equ $ - Inflate_CopyDistance_17

Inflate_CopyDistance_18:
	call Reader_ReadBitsInline_8_DE
	push hl
	exx
	ld e,a
	ld d,513 - 1 >> 8
	jp Writer_Copy_AndNext
Inflate_CopyDistance_18_len: equ $ - Inflate_CopyDistance_18

Inflate_CopyDistance_19:
	call Reader_ReadBitsInline_8_DE
	push hl
	exx
	ld e,a
	ld d,769 - 1 >> 8
	jp Writer_Copy_AndNext
Inflate_CopyDistance_19_len: equ $ - Inflate_CopyDistance_19

Inflate_CopyDistance_20:
	call Reader_ReadBitsInline_8_DE
	ex af,af'
	call Reader_ReadBitsInline_1_DE
	add a,1025 - 1 >> 8
	jp Inflate_CopyAndNext_SetBigDistance
Inflate_CopyDistance_20_len: equ $ - Inflate_CopyDistance_20

Inflate_CopyDistance_21:
	call Reader_ReadBitsInline_8_DE
	ex af,af'
	call Reader_ReadBitsInline_1_DE
	add a,1537 - 1 >> 8
	jp Inflate_CopyAndNext_SetBigDistance
Inflate_CopyDistance_21_len: equ $ - Inflate_CopyDistance_21

Inflate_CopyDistance_22:
	call Reader_ReadBitsInline_8_DE
	ex af,af'
	call Reader_ReadBitsInline_2_DE
	add a,2049 - 1 >> 8
	jp Inflate_CopyAndNext_SetBigDistance
Inflate_CopyDistance_22_len: equ $ - Inflate_CopyDistance_22

Inflate_CopyDistance_23:
	call Reader_ReadBitsInline_8_DE
	ex af,af'
	call Reader_ReadBitsInline_2_DE
	add a,3073 - 1 >> 8
	jp Inflate_CopyAndNext_SetBigDistance
Inflate_CopyDistance_23_len: equ $ - Inflate_CopyDistance_23

Inflate_CopyDistance_24:
	call Reader_ReadBitsInline_8_DE
	ex af,af'
	call Reader_ReadBitsInline_3_DE
	add a,4097 - 1 >> 8
	jp Inflate_CopyAndNext_SetBigDistance
Inflate_CopyDistance_24_len: equ $ - Inflate_CopyDistance_24

Inflate_CopyDistance_25:
	call Reader_ReadBitsInline_8_DE
	ex af,af'
	call Reader_ReadBitsInline_3_DE
	add a,6145 - 1 >> 8
	jp Inflate_CopyAndNext_SetBigDistance
Inflate_CopyDistance_25_len: equ $ - Inflate_CopyDistance_25

Inflate_CopyDistance_26:
	call Reader_ReadBitsInline_8_DE
	ex af,af'
	call Reader_ReadBitsInline_4_DE
	add a,8193 - 1 >> 8
	jp Inflate_CopyAndNext_SetBigDistance
Inflate_CopyDistance_26_len: equ $ - Inflate_CopyDistance_26

Inflate_CopyDistance_27:
	call Reader_ReadBitsInline_8_DE
	ex af,af'
	call Reader_ReadBitsInline_4_DE
	add a,12289 - 1 >> 8
	jp Inflate_CopyAndNext_SetBigDistance
Inflate_CopyDistance_27_len: equ $ - Inflate_CopyDistance_27

Inflate_CopyDistance_28:
	call Reader_ReadBitsInline_8_DE
	ex af,af'
	call Reader_ReadBitsInline_5_DE
	add a,16385 - 1 >> 8
	jp Inflate_CopyAndNext_SetBigDistance
Inflate_CopyDistance_28_len: equ $ - Inflate_CopyDistance_28

Inflate_CopyDistance_29:
	call Reader_ReadBitsInline_8_DE
	ex af,af'
	call Reader_ReadBitsInline_5_DE
	add a,24577 - 1 >> 8
	jp Inflate_CopyAndNext_SetBigDistance
Inflate_CopyDistance_29_len: equ $ - Inflate_CopyDistance_29

; a = distance - 1
; bc = length
; c' = inline bit reader state
; de = inline Reader_bufPos
; iy = Writer_Write_AndNext
Inflate_CopyAndNext_SetSmallDistance:
	push hl
	exx
	ld e,a
	ld d,0
	jp Writer_Copy_AndNext

; a = distance - 1 MSB
; a' = distance - 1 LSB
; bc = length
; c' = inline bit reader state
; de = inline Reader_bufPos
; iy = Writer_Write_AndNext
Inflate_CopyAndNext_SetBigDistance:
	push hl
	exx
	ld d,a
	ex af,af'
	ld e,a
	jp Writer_Copy_AndNext

;
Inflate_distanceSymbols:
	db Inflate_CopyDistance_0_len
	dw Inflate_CopyDistance_0
	db Inflate_CopyDistance_1_len
	dw Inflate_CopyDistance_1
	db Inflate_CopyDistance_2_len
	dw Inflate_CopyDistance_2
	db Inflate_CopyDistance_3_len
	dw Inflate_CopyDistance_3
	db Inflate_CopyDistance_4_len
	dw Inflate_CopyDistance_4
	db Inflate_CopyDistance_5_len
	dw Inflate_CopyDistance_5
	db Inflate_CopyDistance_6_len
	dw Inflate_CopyDistance_6
	db Inflate_CopyDistance_7_len
	dw Inflate_CopyDistance_7
	db Inflate_CopyDistance_8_len
	dw Inflate_CopyDistance_8
	db Inflate_CopyDistance_9_len
	dw Inflate_CopyDistance_9
	db Inflate_CopyDistance_10_len
	dw Inflate_CopyDistance_10
	db Inflate_CopyDistance_11_len
	dw Inflate_CopyDistance_11
	db Inflate_CopyDistance_12_len
	dw Inflate_CopyDistance_12
	db Inflate_CopyDistance_13_len
	dw Inflate_CopyDistance_13
	db Inflate_CopyDistance_14_len
	dw Inflate_CopyDistance_14
	db Inflate_CopyDistance_15_len
	dw Inflate_CopyDistance_15
	db Inflate_CopyDistance_16_len
	dw Inflate_CopyDistance_16
	db Inflate_CopyDistance_17_len
	dw Inflate_CopyDistance_17
	db Inflate_CopyDistance_18_len
	dw Inflate_CopyDistance_18
	db Inflate_CopyDistance_19_len
	dw Inflate_CopyDistance_19
	db Inflate_CopyDistance_20_len
	dw Inflate_CopyDistance_20
	db Inflate_CopyDistance_21_len
	dw Inflate_CopyDistance_21
	db Inflate_CopyDistance_22_len
	dw Inflate_CopyDistance_22
	db Inflate_CopyDistance_23_len
	dw Inflate_CopyDistance_23
	db Inflate_CopyDistance_24_len
	dw Inflate_CopyDistance_24
	db Inflate_CopyDistance_25_len
	dw Inflate_CopyDistance_25
	db Inflate_CopyDistance_26_len
	dw Inflate_CopyDistance_26
	db Inflate_CopyDistance_27_len
	dw Inflate_CopyDistance_27
	db Inflate_CopyDistance_28_len
	dw Inflate_CopyDistance_28
	db Inflate_CopyDistance_29_len
	dw Inflate_CopyDistance_29
	db ThrowInlineLen
	dw ThrowInline
	db ThrowInlineLen
	dw ThrowInline
