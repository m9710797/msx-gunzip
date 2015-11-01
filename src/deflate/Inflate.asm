;
; Inflate implementation
;
Inflate_Inflate:
	call Reader_PrepareReadBitInline
	call Reader_ReadBitsInline_1_DE
	push af
	call Reader_ReadBitsInline_2_DE
	push af
	call Reader_FinishReadBitInline
	pop af
	call Inflate_InflateBlock
	pop af
	or a
	jr z,Inflate_Inflate
	ret

; a = block type
Inflate_InflateBlock:
	and a
	jr z,Inflate_InflateUncompressed
	cp 2
	jr c,Inflate_InflateFixedCompressed
	jr z,Inflate_InflateDynamicCompressed
	ld hl,Inflate_invalidBlockTypeError
	jp Application_TerminateWithError

Inflate_InflateUncompressed: PROC
	ld de,(Reader_bufPos)
	call Reader_Align
	call Reader_Read_DE_fast
	ld c,a
	call Reader_Read_DE_fast
	ld b,a
	call Reader_Read_DE_fast
	ld l,a
	call Reader_Read_DE_fast
	ld h,a
	scf
	adc hl,bc
	ld hl,Inflate_invalidLengthError
	jp nz,Application_TerminateWithError

	ld a,b
	or c
	jr z,End
	ld a,c
	dec bc
	inc b
	ld c,b
	ld b,a

Loop:	call Reader_Read_DE_fast
	call Writer_Write_slow
	djnz Loop
	dec c
	jr nz,Loop

End:	ld (Reader_bufPos),de
	ret
	ENDP

Inflate_InflateFixedCompressed:
	ld bc,FixedAlphabets_literalLengthCodeLengthsCount
	ld de,FixedAlphabets_literalLengthCodeLengths
	ld hl,LiteralTree
	ld iy,Inflate_literalLengthSymbols
	call generate_huffman
	ld hl,LiteralTreeEnd
	ld de,(out_ptr)
	or a
	sbc hl,de
	call c,System_ThrowException

	ld bc,FixedAlphabets_distanceCodeLengthsCount
	ld de,FixedAlphabets_distanceCodeLengths
	ld hl,DistanceTree
	ld iy,Inflate_distanceSymbols
	call generate_huffman
	ld hl,DistanceTreeEnd
	ld de,(out_ptr)
	or a
	sbc hl,de
	call c,System_ThrowException
	jr Inflate_DoInflate

Inflate_InflateDynamicCompressed:
	call ConstructDynamicAlphabets
Inflate_DoInflate:
	ld iy,Writer_Write_AndNext
	call Reader_PrepareReadBitInline
	ld hl,(Writer_bufPos)
	call LiteralTree
	ld (Writer_bufPos),hl
	jp Reader_FinishReadBitInline

; Literal/length alphabet symbols 0-255
; c = inline bit reader state
; de = inline Reader_bufPos
; iy = Writer_Write_AndNext
Inflate_WriteLiteral: REPT 256, ?value
	ld a,?value
	jp iy ; Writer_Write_AndNext
	ENDM

; Literal/length alphabet symbol 256
; c = inline bit reader state
; de = inline Reader_bufPos
; iy = Writer_Write_AndNext
Inflate_EndBlock:
	ret

; Literal/length alphabet symbols 257-285
; c = inline bit reader state
; de = inline Reader_bufPos
; iy = Writer_Write_AndNext
Inflate_CopyLength.0:
	exx
	ld bc,3
	exx
	jp DistanceTree
Inflate_CopyLength.1:
	exx
	ld bc,4
	exx
	jp DistanceTree
Inflate_CopyLength.2:
	exx
	ld bc,5
	exx
	jp DistanceTree
Inflate_CopyLength.3:
	exx
	ld bc,6
	exx
	jp DistanceTree
Inflate_CopyLength.4:
	exx
	ld bc,7
	exx
	jp DistanceTree
Inflate_CopyLength.5:
	exx
	ld bc,8
	exx
	jp DistanceTree
Inflate_CopyLength.6:
	exx
	ld bc,9
	exx
	jp DistanceTree
Inflate_CopyLength.7:
	exx
	ld bc,10
	exx
	jp DistanceTree
Inflate_CopyLength.8:
	call Reader_ReadBitsInline_1_DE
	add a,11
	jp Inflate_DecodeDistance_SetLength
Inflate_CopyLength.9:
	call Reader_ReadBitsInline_1_DE
	add a,13
	jp Inflate_DecodeDistance_SetLength
Inflate_CopyLength.10:
	call Reader_ReadBitsInline_1_DE
	add a,15
	jp Inflate_DecodeDistance_SetLength
Inflate_CopyLength.11:
	call Reader_ReadBitsInline_1_DE
	add a,17
	jp Inflate_DecodeDistance_SetLength
Inflate_CopyLength.12:
	call Reader_ReadBitsInline_2_DE
	add a,19
	jp Inflate_DecodeDistance_SetLength
Inflate_CopyLength.13:
	call Reader_ReadBitsInline_2_DE
	add a,23
	jp Inflate_DecodeDistance_SetLength
Inflate_CopyLength.14:
	call Reader_ReadBitsInline_2_DE
	add a,27
	jp Inflate_DecodeDistance_SetLength
Inflate_CopyLength.15:
	call Reader_ReadBitsInline_2_DE
	add a,31
	jp Inflate_DecodeDistance_SetLength
Inflate_CopyLength.16:
	call Reader_ReadBitsInline_3_DE
	add a,35
	jp Inflate_DecodeDistance_SetLength
Inflate_CopyLength.17:
	call Reader_ReadBitsInline_3_DE
	add a,43
	jp Inflate_DecodeDistance_SetLength
Inflate_CopyLength.18:
	call Reader_ReadBitsInline_3_DE
	add a,51
	jp Inflate_DecodeDistance_SetLength
Inflate_CopyLength.19:
	call Reader_ReadBitsInline_3_DE
	add a,59
	jp Inflate_DecodeDistance_SetLength
Inflate_CopyLength.20:
	call Reader_ReadBitsInline_4_DE
	add a,67
	jp Inflate_DecodeDistance_SetLength
Inflate_CopyLength.21:
	call Reader_ReadBitsInline_4_DE
	add a,83
	jp Inflate_DecodeDistance_SetLength
Inflate_CopyLength.22:
	call Reader_ReadBitsInline_4_DE
	add a,99
	jp Inflate_DecodeDistance_SetLength
Inflate_CopyLength.23:
	call Reader_ReadBitsInline_4_DE
	add a,115
	jp Inflate_DecodeDistance_SetLength
Inflate_CopyLength.24:
	call Reader_ReadBitsInline_5_DE
	add a,131
	jp Inflate_DecodeDistance_SetLength
Inflate_CopyLength.25:
	call Reader_ReadBitsInline_5_DE
	add a,163
	jp Inflate_DecodeDistance_SetLength
Inflate_CopyLength.26:
	call Reader_ReadBitsInline_5_DE
	add a,195
	jp Inflate_DecodeDistance_SetLength
Inflate_CopyLength.27:
	call Reader_ReadBitsInline_5_DE
	add a,227
	exx
	ld c,a
	jp nc,Inflate_DecodeDistance_SetLength_0
	ld b,1
	exx
	jp DistanceTree
Inflate_CopyLength.28:
	exx
	ld bc,258
	exx
	jp DistanceTree

; a = length
; c' = inline bit reader state
; de = inline Reader_bufPos
; iy = Writer_Write_AndNext
Inflate_DecodeDistance_SetLength:
	exx
	ld c,a
Inflate_DecodeDistance_SetLength_0:
	ld b,0
	exx
	jp DistanceTree

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
Inflate_literalLengthSymbols:
	db 4
	dw Inflate_WriteLiteral.0
	db 4
	dw Inflate_WriteLiteral.1
	db 4
	dw Inflate_WriteLiteral.2
	db 4
	dw Inflate_WriteLiteral.3
	db 4
	dw Inflate_WriteLiteral.4
	db 4
	dw Inflate_WriteLiteral.5
	db 4
	dw Inflate_WriteLiteral.6
	db 4
	dw Inflate_WriteLiteral.7
	db 4
	dw Inflate_WriteLiteral.8
	db 4
	dw Inflate_WriteLiteral.9
	db 4
	dw Inflate_WriteLiteral.10
	db 4
	dw Inflate_WriteLiteral.11
	db 4
	dw Inflate_WriteLiteral.12
	db 4
	dw Inflate_WriteLiteral.13
	db 4
	dw Inflate_WriteLiteral.14
	db 4
	dw Inflate_WriteLiteral.15
	db 4
	dw Inflate_WriteLiteral.16
	db 4
	dw Inflate_WriteLiteral.17
	db 4
	dw Inflate_WriteLiteral.18
	db 4
	dw Inflate_WriteLiteral.19
	db 4
	dw Inflate_WriteLiteral.20
	db 4
	dw Inflate_WriteLiteral.21
	db 4
	dw Inflate_WriteLiteral.22
	db 4
	dw Inflate_WriteLiteral.23
	db 4
	dw Inflate_WriteLiteral.24
	db 4
	dw Inflate_WriteLiteral.25
	db 4
	dw Inflate_WriteLiteral.26
	db 4
	dw Inflate_WriteLiteral.27
	db 4
	dw Inflate_WriteLiteral.28
	db 4
	dw Inflate_WriteLiteral.29
	db 4
	dw Inflate_WriteLiteral.30
	db 4
	dw Inflate_WriteLiteral.31
	db 4
	dw Inflate_WriteLiteral.32
	db 4
	dw Inflate_WriteLiteral.33
	db 4
	dw Inflate_WriteLiteral.34
	db 4
	dw Inflate_WriteLiteral.35
	db 4
	dw Inflate_WriteLiteral.36
	db 4
	dw Inflate_WriteLiteral.37
	db 4
	dw Inflate_WriteLiteral.38
	db 4
	dw Inflate_WriteLiteral.39
	db 4
	dw Inflate_WriteLiteral.40
	db 4
	dw Inflate_WriteLiteral.41
	db 4
	dw Inflate_WriteLiteral.42
	db 4
	dw Inflate_WriteLiteral.43
	db 4
	dw Inflate_WriteLiteral.44
	db 4
	dw Inflate_WriteLiteral.45
	db 4
	dw Inflate_WriteLiteral.46
	db 4
	dw Inflate_WriteLiteral.47
	db 4
	dw Inflate_WriteLiteral.48
	db 4
	dw Inflate_WriteLiteral.49
	db 4
	dw Inflate_WriteLiteral.50
	db 4
	dw Inflate_WriteLiteral.51
	db 4
	dw Inflate_WriteLiteral.52
	db 4
	dw Inflate_WriteLiteral.53
	db 4
	dw Inflate_WriteLiteral.54
	db 4
	dw Inflate_WriteLiteral.55
	db 4
	dw Inflate_WriteLiteral.56
	db 4
	dw Inflate_WriteLiteral.57
	db 4
	dw Inflate_WriteLiteral.58
	db 4
	dw Inflate_WriteLiteral.59
	db 4
	dw Inflate_WriteLiteral.60
	db 4
	dw Inflate_WriteLiteral.61
	db 4
	dw Inflate_WriteLiteral.62
	db 4
	dw Inflate_WriteLiteral.63
	db 4
	dw Inflate_WriteLiteral.64
	db 4
	dw Inflate_WriteLiteral.65
	db 4
	dw Inflate_WriteLiteral.66
	db 4
	dw Inflate_WriteLiteral.67
	db 4
	dw Inflate_WriteLiteral.68
	db 4
	dw Inflate_WriteLiteral.69
	db 4
	dw Inflate_WriteLiteral.70
	db 4
	dw Inflate_WriteLiteral.71
	db 4
	dw Inflate_WriteLiteral.72
	db 4
	dw Inflate_WriteLiteral.73
	db 4
	dw Inflate_WriteLiteral.74
	db 4
	dw Inflate_WriteLiteral.75
	db 4
	dw Inflate_WriteLiteral.76
	db 4
	dw Inflate_WriteLiteral.77
	db 4
	dw Inflate_WriteLiteral.78
	db 4
	dw Inflate_WriteLiteral.79
	db 4
	dw Inflate_WriteLiteral.80
	db 4
	dw Inflate_WriteLiteral.81
	db 4
	dw Inflate_WriteLiteral.82
	db 4
	dw Inflate_WriteLiteral.83
	db 4
	dw Inflate_WriteLiteral.84
	db 4
	dw Inflate_WriteLiteral.85
	db 4
	dw Inflate_WriteLiteral.86
	db 4
	dw Inflate_WriteLiteral.87
	db 4
	dw Inflate_WriteLiteral.88
	db 4
	dw Inflate_WriteLiteral.89
	db 4
	dw Inflate_WriteLiteral.90
	db 4
	dw Inflate_WriteLiteral.91
	db 4
	dw Inflate_WriteLiteral.92
	db 4
	dw Inflate_WriteLiteral.93
	db 4
	dw Inflate_WriteLiteral.94
	db 4
	dw Inflate_WriteLiteral.95
	db 4
	dw Inflate_WriteLiteral.96
	db 4
	dw Inflate_WriteLiteral.97
	db 4
	dw Inflate_WriteLiteral.98
	db 4
	dw Inflate_WriteLiteral.99
	db 4
	dw Inflate_WriteLiteral.100
	db 4
	dw Inflate_WriteLiteral.101
	db 4
	dw Inflate_WriteLiteral.102
	db 4
	dw Inflate_WriteLiteral.103
	db 4
	dw Inflate_WriteLiteral.104
	db 4
	dw Inflate_WriteLiteral.105
	db 4
	dw Inflate_WriteLiteral.106
	db 4
	dw Inflate_WriteLiteral.107
	db 4
	dw Inflate_WriteLiteral.108
	db 4
	dw Inflate_WriteLiteral.109
	db 4
	dw Inflate_WriteLiteral.110
	db 4
	dw Inflate_WriteLiteral.111
	db 4
	dw Inflate_WriteLiteral.112
	db 4
	dw Inflate_WriteLiteral.113
	db 4
	dw Inflate_WriteLiteral.114
	db 4
	dw Inflate_WriteLiteral.115
	db 4
	dw Inflate_WriteLiteral.116
	db 4
	dw Inflate_WriteLiteral.117
	db 4
	dw Inflate_WriteLiteral.118
	db 4
	dw Inflate_WriteLiteral.119
	db 4
	dw Inflate_WriteLiteral.120
	db 4
	dw Inflate_WriteLiteral.121
	db 4
	dw Inflate_WriteLiteral.122
	db 4
	dw Inflate_WriteLiteral.123
	db 4
	dw Inflate_WriteLiteral.124
	db 4
	dw Inflate_WriteLiteral.125
	db 4
	dw Inflate_WriteLiteral.126
	db 4
	dw Inflate_WriteLiteral.127
	db 4
	dw Inflate_WriteLiteral.128
	db 4
	dw Inflate_WriteLiteral.129
	db 4
	dw Inflate_WriteLiteral.130
	db 4
	dw Inflate_WriteLiteral.131
	db 4
	dw Inflate_WriteLiteral.132
	db 4
	dw Inflate_WriteLiteral.133
	db 4
	dw Inflate_WriteLiteral.134
	db 4
	dw Inflate_WriteLiteral.135
	db 4
	dw Inflate_WriteLiteral.136
	db 4
	dw Inflate_WriteLiteral.137
	db 4
	dw Inflate_WriteLiteral.138
	db 4
	dw Inflate_WriteLiteral.139
	db 4
	dw Inflate_WriteLiteral.140
	db 4
	dw Inflate_WriteLiteral.141
	db 4
	dw Inflate_WriteLiteral.142
	db 4
	dw Inflate_WriteLiteral.143
	db 4
	dw Inflate_WriteLiteral.144
	db 4
	dw Inflate_WriteLiteral.145
	db 4
	dw Inflate_WriteLiteral.146
	db 4
	dw Inflate_WriteLiteral.147
	db 4
	dw Inflate_WriteLiteral.148
	db 4
	dw Inflate_WriteLiteral.149
	db 4
	dw Inflate_WriteLiteral.150
	db 4
	dw Inflate_WriteLiteral.151
	db 4
	dw Inflate_WriteLiteral.152
	db 4
	dw Inflate_WriteLiteral.153
	db 4
	dw Inflate_WriteLiteral.154
	db 4
	dw Inflate_WriteLiteral.155
	db 4
	dw Inflate_WriteLiteral.156
	db 4
	dw Inflate_WriteLiteral.157
	db 4
	dw Inflate_WriteLiteral.158
	db 4
	dw Inflate_WriteLiteral.159
	db 4
	dw Inflate_WriteLiteral.160
	db 4
	dw Inflate_WriteLiteral.161
	db 4
	dw Inflate_WriteLiteral.162
	db 4
	dw Inflate_WriteLiteral.163
	db 4
	dw Inflate_WriteLiteral.164
	db 4
	dw Inflate_WriteLiteral.165
	db 4
	dw Inflate_WriteLiteral.166
	db 4
	dw Inflate_WriteLiteral.167
	db 4
	dw Inflate_WriteLiteral.168
	db 4
	dw Inflate_WriteLiteral.169
	db 4
	dw Inflate_WriteLiteral.170
	db 4
	dw Inflate_WriteLiteral.171
	db 4
	dw Inflate_WriteLiteral.172
	db 4
	dw Inflate_WriteLiteral.173
	db 4
	dw Inflate_WriteLiteral.174
	db 4
	dw Inflate_WriteLiteral.175
	db 4
	dw Inflate_WriteLiteral.176
	db 4
	dw Inflate_WriteLiteral.177
	db 4
	dw Inflate_WriteLiteral.178
	db 4
	dw Inflate_WriteLiteral.179
	db 4
	dw Inflate_WriteLiteral.180
	db 4
	dw Inflate_WriteLiteral.181
	db 4
	dw Inflate_WriteLiteral.182
	db 4
	dw Inflate_WriteLiteral.183
	db 4
	dw Inflate_WriteLiteral.184
	db 4
	dw Inflate_WriteLiteral.185
	db 4
	dw Inflate_WriteLiteral.186
	db 4
	dw Inflate_WriteLiteral.187
	db 4
	dw Inflate_WriteLiteral.188
	db 4
	dw Inflate_WriteLiteral.189
	db 4
	dw Inflate_WriteLiteral.190
	db 4
	dw Inflate_WriteLiteral.191
	db 4
	dw Inflate_WriteLiteral.192
	db 4
	dw Inflate_WriteLiteral.193
	db 4
	dw Inflate_WriteLiteral.194
	db 4
	dw Inflate_WriteLiteral.195
	db 4
	dw Inflate_WriteLiteral.196
	db 4
	dw Inflate_WriteLiteral.197
	db 4
	dw Inflate_WriteLiteral.198
	db 4
	dw Inflate_WriteLiteral.199
	db 4
	dw Inflate_WriteLiteral.200
	db 4
	dw Inflate_WriteLiteral.201
	db 4
	dw Inflate_WriteLiteral.202
	db 4
	dw Inflate_WriteLiteral.203
	db 4
	dw Inflate_WriteLiteral.204
	db 4
	dw Inflate_WriteLiteral.205
	db 4
	dw Inflate_WriteLiteral.206
	db 4
	dw Inflate_WriteLiteral.207
	db 4
	dw Inflate_WriteLiteral.208
	db 4
	dw Inflate_WriteLiteral.209
	db 4
	dw Inflate_WriteLiteral.210
	db 4
	dw Inflate_WriteLiteral.211
	db 4
	dw Inflate_WriteLiteral.212
	db 4
	dw Inflate_WriteLiteral.213
	db 4
	dw Inflate_WriteLiteral.214
	db 4
	dw Inflate_WriteLiteral.215
	db 4
	dw Inflate_WriteLiteral.216
	db 4
	dw Inflate_WriteLiteral.217
	db 4
	dw Inflate_WriteLiteral.218
	db 4
	dw Inflate_WriteLiteral.219
	db 4
	dw Inflate_WriteLiteral.220
	db 4
	dw Inflate_WriteLiteral.221
	db 4
	dw Inflate_WriteLiteral.222
	db 4
	dw Inflate_WriteLiteral.223
	db 4
	dw Inflate_WriteLiteral.224
	db 4
	dw Inflate_WriteLiteral.225
	db 4
	dw Inflate_WriteLiteral.226
	db 4
	dw Inflate_WriteLiteral.227
	db 4
	dw Inflate_WriteLiteral.228
	db 4
	dw Inflate_WriteLiteral.229
	db 4
	dw Inflate_WriteLiteral.230
	db 4
	dw Inflate_WriteLiteral.231
	db 4
	dw Inflate_WriteLiteral.232
	db 4
	dw Inflate_WriteLiteral.233
	db 4
	dw Inflate_WriteLiteral.234
	db 4
	dw Inflate_WriteLiteral.235
	db 4
	dw Inflate_WriteLiteral.236
	db 4
	dw Inflate_WriteLiteral.237
	db 4
	dw Inflate_WriteLiteral.238
	db 4
	dw Inflate_WriteLiteral.239
	db 4
	dw Inflate_WriteLiteral.240
	db 4
	dw Inflate_WriteLiteral.241
	db 4
	dw Inflate_WriteLiteral.242
	db 4
	dw Inflate_WriteLiteral.243
	db 4
	dw Inflate_WriteLiteral.244
	db 4
	dw Inflate_WriteLiteral.245
	db 4
	dw Inflate_WriteLiteral.246
	db 4
	dw Inflate_WriteLiteral.247
	db 4
	dw Inflate_WriteLiteral.248
	db 4
	dw Inflate_WriteLiteral.249
	db 4
	dw Inflate_WriteLiteral.250
	db 4
	dw Inflate_WriteLiteral.251
	db 4
	dw Inflate_WriteLiteral.252
	db 4
	dw Inflate_WriteLiteral.253
	db 4
	dw Inflate_WriteLiteral.254
	db 4
	dw Inflate_WriteLiteral.255

	db 1
	dw Inflate_EndBlock

	db 8
	dw Inflate_CopyLength.0
	db 8
	dw Inflate_CopyLength.1
	db 8
	dw Inflate_CopyLength.2
	db 8
	dw Inflate_CopyLength.3
	db 8
	dw Inflate_CopyLength.4
	db 8
	dw Inflate_CopyLength.5
	db 8
	dw Inflate_CopyLength.6
	db 8
	dw Inflate_CopyLength.7
	db 8
	dw Inflate_CopyLength.8
	db 8
	dw Inflate_CopyLength.9
	db 8
	dw Inflate_CopyLength.10
	db 8
	dw Inflate_CopyLength.11
	db 8
	dw Inflate_CopyLength.12
	db 8
	dw Inflate_CopyLength.13
	db 8
	dw Inflate_CopyLength.14
	db 8
	dw Inflate_CopyLength.15
	db 8
	dw Inflate_CopyLength.16
	db 8
	dw Inflate_CopyLength.17
	db 8
	dw Inflate_CopyLength.18
	db 8
	dw Inflate_CopyLength.19
	db 8
	dw Inflate_CopyLength.20
	db 8
	dw Inflate_CopyLength.21
	db 8
	dw Inflate_CopyLength.22
	db 8
	dw Inflate_CopyLength.23
	db 8
	dw Inflate_CopyLength.24
	db 8
	dw Inflate_CopyLength.25
	db 8
	dw Inflate_CopyLength.26
	db 16
	dw Inflate_CopyLength.27
	db 8
	dw Inflate_CopyLength.28
	db 3
	dw System_ThrowException_
	db 3
	dw System_ThrowException_

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
	db System_ThrowException_len
	dw System_ThrowException_
	db System_ThrowException_len
	dw System_ThrowException_

Inflate_invalidBlockTypeError:
	db "Invalid block type.",13,10,0

Inflate_invalidLengthError:
	db "Invalid length.",13,10,0









; Generate Huffman decoding function
;
; In:
;  [bc] = number of symbols
;  [de] = table containing length of each symbol
;  [hl] = output-buffer (cannot start below 0x100)
;  [iy] = table containing pointer to leaf-routine for each symbol
; Out:
;  output-buffer filled with decoding function
;  (root)    = start of output-buffer (= input parameter)
;  (out_ptr) = end   of output-buffer
; Modifies:
;  - all registers
;  - variables scratch_buf,root,out_ptr,length_ptr are changed, but can be
;    freely used outside this routine. IOW it's all scratch area.
; Requires:
;  scratch_buf must be 256-byte aligned, must be at least 32 bytes in size

generate_huffman: PROC
	ld (root),hl
	ld (out_ptr),hl
	ld (length_ptr),de
	push bc

	; clear length-counts table
	ld hl,scratch_buf
	ld de,scratch_buf + 1
	ld bc,(2 * 16) - 1
	ld (hl),b		; 0
	ldir

	pop bc			; bc = number of symbols
	push bc

	; count occurrences of each symbol-length
	ld de,(length_ptr)
	ld h,scratch_buf >> 8	; scratch_buf used as 'int16_t countBuf[16]'
count_loop:
	ld a,(de)		; symbol length
	inc de
	add a,a
	jr z,count_next
	ld l,a
	inc (hl)		; ++countBuf[length]
	jr nz,count_next
	inc l
	inc (hl)
count_next:
	dec bc
	ld a,b
	or c
	jr nz,count_loop

	; calculate next-codes
	; before this loop 'scratch_buf' contains 'uint16_t countBuf[16]'
	; after  this loop 'scratch_buf' contains 'uint16_t nextCode[16]'
	; IOW 'countBuf' is transformed in-place to 'nextCode'
	ld a,16
	ld d,b			; b = 0
	ld e,b			; de = t = 0
	ld l,b			; hl = scratch_buf
next_code_loop:
	ld c,(hl)
	ld (hl),e
	inc l
	ld b,(hl)		; bc = countBuf[i]
	ld (hl),d		; nextCode[i] = t
	inc l
	ex de,hl
	add hl,bc
	add hl,hl		; t = (t + countBuf[i]) * 2
	ex de,hl
	dec a
	jr nz,next_code_loop

	pop bc			; bc = number of symbols

symbol_loop:
	; Process the next symbol. Add it to the (partially constructed)
	; Huffman tree, following exiting nodes and creating new nodes along
	; the way.
	push bc			; bc = number of remaining symbols

	ld hl,(length_ptr)
	ld c,(hl)		; c = length of symbol
	inc hl
	ld (length_ptr),hl	; ++length_ptr
	ld a,c
	add a,a
	jp z,next_symbol
	ld l,a
	ld h,scratch_buf >> 8	; hl = &nextCode[length]

	ld e,(hl)
	inc l
	ld d,(hl)		; de = code = nextCode[length]
	push de
	pop ix			; ix = code
	inc de
	ld (hl),d
	dec l
	ld (hl),e		; ++nextCode[length]

	ld a,16
	sub c			; c = symbol length
	ld b,a
shift_loop:
	add ix,ix		; carry-flag clear
	djnz shift_loop

	ld hl,(root)		; hl = root node
	ld de,(out_ptr)		; de = location to create new node
	; assert(carry-flag not set)
	sbc hl,de		; does update zero flag
	add hl,de		; does not update zero flag
	jr nz,follow		; de == hl?
	; de == hl == root == out_ptr -> only happens for the very first symbol

create_loop:
	; invariant: hl -> free space in output buffer
	;            ix -> remaining code bits (MSB aligned)
	;            c  -> number of remaining bits
	;            b  -> 0
	; generate 'Reader_ReadBitInline_IX'
	ld (hl),0CBH		; SRL C
	inc hl
	ld (hl),39H
	inc hl
	ld (hl),0CCH		; CALL Z,nn
	inc hl
	ld (hl),Reader_ReadBitInline_NextByte_DE & 0FFH
	inc hl
	ld (hl),Reader_ReadBitInline_NextByte_DE >> 8
	inc hl

	; generate JP NC,0 / JP C,0
	add ix,ix		; shift code -> output bit to carry
	sbc a,a			; a = carry ? 0xff : 0x00
	and 8			; a = carry ? 0x08 : 0x00
	xor 0DAH		; a = carry ? 0xD2 : 0xDA
	ld (hl),a		; carry ? JP_NC : JP_C
	inc hl
	inc hl			; skip low address byte
	ld (hl),b		; b = 0   only mark high address byte
	inc hl

	; next code bit
	dec c			; --length
	jr nz,create_loop

	; Create leaf node. ATM this is a jump to the symbol routine.
	; TODO in the future also inline this jump
debug:
	ld c,(iy+0)
	ld b,0		; bc = length
	ld e,(iy+1)
	ld d,(iy+2)
	ex de,hl	; hl = routine / de = leaf-node
	ldir
	ld (out_ptr),de		; update new output position
	jr next_symbol

follow_loop:
	add ix,ix		; shift code -> output bit to carry
	sbc a,a			; a = carry ? 0xff : 0x00
	and 8			; a = carry ? 0x08 : 0x00
	xor 0DAH		; a = carry ? 0xD2 : 0xDA
	cp (hl)			; compare with conditional-jump opcode
	inc hl
	inc hl			; skip to high address byte of JP cc,nn
	jr nz,follow_conditional

	; follow fall-through path
	inc hl			; fully skip JP cc,nn instruction
	jr follow

follow_conditional:
	ld a,(hl)		; high byte of conditional jump
	or a			; address already filled-in?
	jr nz,follow_existing

	; path does not yet exist
	ld (hl),d		; de = out_ptr
	dec hl
	ld (hl),e		; fill-in address to new node
	ex de,hl
	jr create_loop		; create that node

follow_existing:
	dec hl
	ld l,(hl)		; low  address byte
	ld h,a			; high address byte

follow:	; invariant: hl = current (existing) huffman node
	;	     de = free buffer space (out_ptr)
	;            ix -> remaining code bits (MSB aligned)
	;            c  -> number of remaining bits
	;            b -> 0
	inc hl
	inc hl
	inc hl
	inc hl
	inc hl			; skip Reader_ReadBitInline_IX
	dec c
	jr nz,follow_loop

	; reached an existing leaf node, fill-in jump-address to symbol-routine
	inc hl			; skip conditional jump opcode
	ld a,(iy+1)
	ld (hl),a
	inc hl
	ld a,(iy+2)
	ld (hl),a

next_symbol:
	inc iy
	inc iy
	inc iy
	pop bc			; bc = number of remaining symbols
	dec bc
	ld a,b
	or c
	jp nz,symbol_loop
	ret
	ENDP

root:		dw 0
length_ptr:	dw 0
out_ptr:	dw 0
