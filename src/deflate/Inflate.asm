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
	jp ExitWithError

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
	jp nz,ExitWithError

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
	call c,ThrowException

	ld bc,FixedAlphabets_distanceCodeLengthsCount
	ld de,FixedAlphabets_distanceCodeLengths
	ld hl,DistanceTree
	ld iy,Inflate_distanceSymbols
	call generate_huffman
	ld hl,DistanceTreeEnd
	ld de,(out_ptr)
	or a
	sbc hl,de
	call c,ThrowException
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
WriteLit00:	xor a		; special case
		jp iy		; Writer_Write_AndNext
WriteLit01:	ld a,#01
		jp iy
WriteLit02:	ld a,#02
		jp iy
WriteLit03:	ld a,#03
		jp iy
WriteLit04:	ld a,#04
		jp iy
WriteLit05:	ld a,#05
		jp iy
WriteLit06:	ld a,#06
		jp iy
WriteLit07:	ld a,#07
		jp iy
WriteLit08:	ld a,#08
		jp iy
WriteLit09:	ld a,#09
		jp iy
WriteLit0A:	ld a,#0A
		jp iy
WriteLit0B:	ld a,#0B
		jp iy
WriteLit0C:	ld a,#0C
		jp iy
WriteLit0D:	ld a,#0D
		jp iy
WriteLit0E:	ld a,#0E
		jp iy
WriteLit0F:	ld a,#0F
		jp iy
WriteLit10:	ld a,#10
		jp iy
WriteLit11:	ld a,#11
		jp iy
WriteLit12:	ld a,#12
		jp iy
WriteLit13:	ld a,#13
		jp iy
WriteLit14:	ld a,#14
		jp iy
WriteLit15:	ld a,#15
		jp iy
WriteLit16:	ld a,#16
		jp iy
WriteLit17:	ld a,#17
		jp iy
WriteLit18:	ld a,#18
		jp iy
WriteLit19:	ld a,#19
		jp iy
WriteLit1A:	ld a,#1A
		jp iy
WriteLit1B:	ld a,#1B
		jp iy
WriteLit1C:	ld a,#1C
		jp iy
WriteLit1D:	ld a,#1D
		jp iy
WriteLit1E:	ld a,#1E
		jp iy
WriteLit1F:	ld a,#1F
		jp iy
WriteLit20:	ld a,#20
		jp iy
WriteLit21:	ld a,#21
		jp iy
WriteLit22:	ld a,#22
		jp iy
WriteLit23:	ld a,#23
		jp iy
WriteLit24:	ld a,#24
		jp iy
WriteLit25:	ld a,#25
		jp iy
WriteLit26:	ld a,#26
		jp iy
WriteLit27:	ld a,#27
		jp iy
WriteLit28:	ld a,#28
		jp iy
WriteLit29:	ld a,#29
		jp iy
WriteLit2A:	ld a,#2A
		jp iy
WriteLit2B:	ld a,#2B
		jp iy
WriteLit2C:	ld a,#2C
		jp iy
WriteLit2D:	ld a,#2D
		jp iy
WriteLit2E:	ld a,#2E
		jp iy
WriteLit2F:	ld a,#2F
		jp iy
WriteLit30:	ld a,#30
		jp iy
WriteLit31:	ld a,#31
		jp iy
WriteLit32:	ld a,#32
		jp iy
WriteLit33:	ld a,#33
		jp iy
WriteLit34:	ld a,#34
		jp iy
WriteLit35:	ld a,#35
		jp iy
WriteLit36:	ld a,#36
		jp iy
WriteLit37:	ld a,#37
		jp iy
WriteLit38:	ld a,#38
		jp iy
WriteLit39:	ld a,#39
		jp iy
WriteLit3A:	ld a,#3A
		jp iy
WriteLit3B:	ld a,#3B
		jp iy
WriteLit3C:	ld a,#3C
		jp iy
WriteLit3D:	ld a,#3D
		jp iy
WriteLit3E:	ld a,#3E
		jp iy
WriteLit3F:	ld a,#3F
		jp iy
WriteLit40:	ld a,#40
		jp iy
WriteLit41:	ld a,#41
		jp iy
WriteLit42:	ld a,#42
		jp iy
WriteLit43:	ld a,#43
		jp iy
WriteLit44:	ld a,#44
		jp iy
WriteLit45:	ld a,#45
		jp iy
WriteLit46:	ld a,#46
		jp iy
WriteLit47:	ld a,#47
		jp iy
WriteLit48:	ld a,#48
		jp iy
WriteLit49:	ld a,#49
		jp iy
WriteLit4A:	ld a,#4A
		jp iy
WriteLit4B:	ld a,#4B
		jp iy
WriteLit4C:	ld a,#4C
		jp iy
WriteLit4D:	ld a,#4D
		jp iy
WriteLit4E:	ld a,#4E
		jp iy
WriteLit4F:	ld a,#4F
		jp iy
WriteLit50:	ld a,#50
		jp iy
WriteLit51:	ld a,#51
		jp iy
WriteLit52:	ld a,#52
		jp iy
WriteLit53:	ld a,#53
		jp iy
WriteLit54:	ld a,#54
		jp iy
WriteLit55:	ld a,#55
		jp iy
WriteLit56:	ld a,#56
		jp iy
WriteLit57:	ld a,#57
		jp iy
WriteLit58:	ld a,#58
		jp iy
WriteLit59:	ld a,#59
		jp iy
WriteLit5A:	ld a,#5A
		jp iy
WriteLit5B:	ld a,#5B
		jp iy
WriteLit5C:	ld a,#5C
		jp iy
WriteLit5D:	ld a,#5D
		jp iy
WriteLit5E:	ld a,#5E
		jp iy
WriteLit5F:	ld a,#5F
		jp iy
WriteLit60:	ld a,#60
		jp iy
WriteLit61:	ld a,#61
		jp iy
WriteLit62:	ld a,#62
		jp iy
WriteLit63:	ld a,#63
		jp iy
WriteLit64:	ld a,#64
		jp iy
WriteLit65:	ld a,#65
		jp iy
WriteLit66:	ld a,#66
		jp iy
WriteLit67:	ld a,#67
		jp iy
WriteLit68:	ld a,#68
		jp iy
WriteLit69:	ld a,#69
		jp iy
WriteLit6A:	ld a,#6A
		jp iy
WriteLit6B:	ld a,#6B
		jp iy
WriteLit6C:	ld a,#6C
		jp iy
WriteLit6D:	ld a,#6D
		jp iy
WriteLit6E:	ld a,#6E
		jp iy
WriteLit6F:	ld a,#6F
		jp iy
WriteLit70:	ld a,#70
		jp iy
WriteLit71:	ld a,#71
		jp iy
WriteLit72:	ld a,#72
		jp iy
WriteLit73:	ld a,#73
		jp iy
WriteLit74:	ld a,#74
		jp iy
WriteLit75:	ld a,#75
		jp iy
WriteLit76:	ld a,#76
		jp iy
WriteLit77:	ld a,#77
		jp iy
WriteLit78:	ld a,#78
		jp iy
WriteLit79:	ld a,#79
		jp iy
WriteLit7A:	ld a,#7A
		jp iy
WriteLit7B:	ld a,#7B
		jp iy
WriteLit7C:	ld a,#7C
		jp iy
WriteLit7D:	ld a,#7D
		jp iy
WriteLit7E:	ld a,#7E
		jp iy
WriteLit7F:	ld a,#7F
		jp iy
WriteLit80:	ld a,#80
		jp iy
WriteLit81:	ld a,#81
		jp iy
WriteLit82:	ld a,#82
		jp iy
WriteLit83:	ld a,#83
		jp iy
WriteLit84:	ld a,#84
		jp iy
WriteLit85:	ld a,#85
		jp iy
WriteLit86:	ld a,#86
		jp iy
WriteLit87:	ld a,#87
		jp iy
WriteLit88:	ld a,#88
		jp iy
WriteLit89:	ld a,#89
		jp iy
WriteLit8A:	ld a,#8A
		jp iy
WriteLit8B:	ld a,#8B
		jp iy
WriteLit8C:	ld a,#8C
		jp iy
WriteLit8D:	ld a,#8D
		jp iy
WriteLit8E:	ld a,#8E
		jp iy
WriteLit8F:	ld a,#8F
		jp iy
WriteLit90:	ld a,#90
		jp iy
WriteLit91:	ld a,#91
		jp iy
WriteLit92:	ld a,#92
		jp iy
WriteLit93:	ld a,#93
		jp iy
WriteLit94:	ld a,#94
		jp iy
WriteLit95:	ld a,#95
		jp iy
WriteLit96:	ld a,#96
		jp iy
WriteLit97:	ld a,#97
		jp iy
WriteLit98:	ld a,#98
		jp iy
WriteLit99:	ld a,#99
		jp iy
WriteLit9A:	ld a,#9A
		jp iy
WriteLit9B:	ld a,#9B
		jp iy
WriteLit9C:	ld a,#9C
		jp iy
WriteLit9D:	ld a,#9D
		jp iy
WriteLit9E:	ld a,#9E
		jp iy
WriteLit9F:	ld a,#9F
		jp iy
WriteLitA0:	ld a,#A0
		jp iy
WriteLitA1:	ld a,#A1
		jp iy
WriteLitA2:	ld a,#A2
		jp iy
WriteLitA3:	ld a,#A3
		jp iy
WriteLitA4:	ld a,#A4
		jp iy
WriteLitA5:	ld a,#A5
		jp iy
WriteLitA6:	ld a,#A6
		jp iy
WriteLitA7:	ld a,#A7
		jp iy
WriteLitA8:	ld a,#A8
		jp iy
WriteLitA9:	ld a,#A9
		jp iy
WriteLitAA:	ld a,#AA
		jp iy
WriteLitAB:	ld a,#AB
		jp iy
WriteLitAC:	ld a,#AC
		jp iy
WriteLitAD:	ld a,#AD
		jp iy
WriteLitAE:	ld a,#AE
		jp iy
WriteLitAF:	ld a,#AF
		jp iy
WriteLitB0:	ld a,#B0
		jp iy
WriteLitB1:	ld a,#B1
		jp iy
WriteLitB2:	ld a,#B2
		jp iy
WriteLitB3:	ld a,#B3
		jp iy
WriteLitB4:	ld a,#B4
		jp iy
WriteLitB5:	ld a,#B5
		jp iy
WriteLitB6:	ld a,#B6
		jp iy
WriteLitB7:	ld a,#B7
		jp iy
WriteLitB8:	ld a,#B8
		jp iy
WriteLitB9:	ld a,#B9
		jp iy
WriteLitBA:	ld a,#BA
		jp iy
WriteLitBB:	ld a,#BB
		jp iy
WriteLitBC:	ld a,#BC
		jp iy
WriteLitBD:	ld a,#BD
		jp iy
WriteLitBE:	ld a,#BE
		jp iy
WriteLitBF:	ld a,#BF
		jp iy
WriteLitC0:	ld a,#C0
		jp iy
WriteLitC1:	ld a,#C1
		jp iy
WriteLitC2:	ld a,#C2
		jp iy
WriteLitC3:	ld a,#C3
		jp iy
WriteLitC4:	ld a,#C4
		jp iy
WriteLitC5:	ld a,#C5
		jp iy
WriteLitC6:	ld a,#C6
		jp iy
WriteLitC7:	ld a,#C7
		jp iy
WriteLitC8:	ld a,#C8
		jp iy
WriteLitC9:	ld a,#C9
		jp iy
WriteLitCA:	ld a,#CA
		jp iy
WriteLitCB:	ld a,#CB
		jp iy
WriteLitCC:	ld a,#CC
		jp iy
WriteLitCD:	ld a,#CD
		jp iy
WriteLitCE:	ld a,#CE
		jp iy
WriteLitCF:	ld a,#CF
		jp iy
WriteLitD0:	ld a,#D0
		jp iy
WriteLitD1:	ld a,#D1
		jp iy
WriteLitD2:	ld a,#D2
		jp iy
WriteLitD3:	ld a,#D3
		jp iy
WriteLitD4:	ld a,#D4
		jp iy
WriteLitD5:	ld a,#D5
		jp iy
WriteLitD6:	ld a,#D6
		jp iy
WriteLitD7:	ld a,#D7
		jp iy
WriteLitD8:	ld a,#D8
		jp iy
WriteLitD9:	ld a,#D9
		jp iy
WriteLitDA:	ld a,#DA
		jp iy
WriteLitDB:	ld a,#DB
		jp iy
WriteLitDC:	ld a,#DC
		jp iy
WriteLitDD:	ld a,#DD
		jp iy
WriteLitDE:	ld a,#DE
		jp iy
WriteLitDF:	ld a,#DF
		jp iy
WriteLitE0:	ld a,#E0
		jp iy
WriteLitE1:	ld a,#E1
		jp iy
WriteLitE2:	ld a,#E2
		jp iy
WriteLitE3:	ld a,#E3
		jp iy
WriteLitE4:	ld a,#E4
		jp iy
WriteLitE5:	ld a,#E5
		jp iy
WriteLitE6:	ld a,#E6
		jp iy
WriteLitE7:	ld a,#E7
		jp iy
WriteLitE8:	ld a,#E8
		jp iy
WriteLitE9:	ld a,#E9
		jp iy
WriteLitEA:	ld a,#EA
		jp iy
WriteLitEB:	ld a,#EB
		jp iy
WriteLitEC:	ld a,#EC
		jp iy
WriteLitED:	ld a,#ED
		jp iy
WriteLitEE:	ld a,#EE
		jp iy
WriteLitEF:	ld a,#EF
		jp iy
WriteLitF0:	ld a,#F0
		jp iy
WriteLitF1:	ld a,#F1
		jp iy
WriteLitF2:	ld a,#F2
		jp iy
WriteLitF3:	ld a,#F3
		jp iy
WriteLitF4:	ld a,#F4
		jp iy
WriteLitF5:	ld a,#F5
		jp iy
WriteLitF6:	ld a,#F6
		jp iy
WriteLitF7:	ld a,#F7
		jp iy
WriteLitF8:	ld a,#F8
		jp iy
WriteLitF9:	ld a,#F9
		jp iy
WriteLitFA:	ld a,#FA
		jp iy
WriteLitFB:	ld a,#FB
		jp iy
WriteLitFC:	ld a,#FC
		jp iy
WriteLitFD:	ld a,#FD
		jp iy
WriteLitFE:	ld a,#FE
		jp iy
WriteLitFF:	ld a,#FF
		jp iy

WriteLitLen00:	equ WriteLit01 - WriteLit00	; special case for 00
WriteLitLen:	equ WriteLit02 - WriteLit01	; all other cases

; Literal/length alphabet symbol 256
; c = inline bit reader state
; de = inline Reader_bufPos
; iy = Writer_Write_AndNext
EndBlock:	ret
EndBlockLen:	equ $ - EndBlock

; Literal/length alphabet symbols 257-285
; c = inline bit reader state
; de = inline Reader_bufPos
; iy = Writer_Write_AndNext
CopyLen0:	exx
		ld bc,3
		exx
		jp DistanceTree
CopyLen0Len:	equ $ - CopyLen0

CopyLen1:	exx
		ld bc,4
		exx
		jp DistanceTree
CopyLen1Len:	equ $ - CopyLen1

CopyLen2:	exx
		ld bc,5
		exx
		jp DistanceTree
CopyLen2Len:	equ $ - CopyLen2

CopyLen3:	exx
		ld bc,6
		exx
		jp DistanceTree
CopyLen3Len:	equ $ - CopyLen3

CopyLen4:	exx
		ld bc,7
		exx
		jp DistanceTree
CopyLen4Len:	equ $ - CopyLen4

CopyLen5:	exx
		ld bc,8
		exx
		jp DistanceTree
CopyLen5Len:	equ $ - CopyLen5

CopyLen6:	exx
		ld bc,9
		exx
		jp DistanceTree
CopyLen6Len:	equ $ - CopyLen6

CopyLen7:	exx
		ld bc,10
		exx
		jp DistanceTree
CopyLen7Len:	equ $ - CopyLen7

CopyLen8:	call Reader_ReadBitsInline_1_DE
		add a,11
		jp Inflate_DecodeDistance_SetLength
CopyLen8Len:	equ $ - CopyLen8

CopyLen9:	call Reader_ReadBitsInline_1_DE
		add a,13
		jp Inflate_DecodeDistance_SetLength
CopyLen9Len:	equ $ - CopyLen9

CopyLen10:	call Reader_ReadBitsInline_1_DE
		add a,15
		jp Inflate_DecodeDistance_SetLength
CopyLen10Len:	equ $ - CopyLen10

CopyLen11:	call Reader_ReadBitsInline_1_DE
		add a,17
		jp Inflate_DecodeDistance_SetLength
CopyLen11Len:	equ $ - CopyLen11

CopyLen12:	call Reader_ReadBitsInline_2_DE
		add a,19
		jp Inflate_DecodeDistance_SetLength
CopyLen12Len:	equ $ - CopyLen12

CopyLen13:	call Reader_ReadBitsInline_2_DE
		add a,23
		jp Inflate_DecodeDistance_SetLength
CopyLen13Len:	equ $ - CopyLen13

CopyLen14:	call Reader_ReadBitsInline_2_DE
		add a,27
		jp Inflate_DecodeDistance_SetLength
CopyLen14Len:	equ $ - CopyLen14

CopyLen15:	call Reader_ReadBitsInline_2_DE
		add a,31
		jp Inflate_DecodeDistance_SetLength
CopyLen15Len:	equ $ - CopyLen15

CopyLen16:	call Reader_ReadBitsInline_3_DE
		add a,35
		jp Inflate_DecodeDistance_SetLength
CopyLen16Len:	equ $ - CopyLen16

CopyLen17:	call Reader_ReadBitsInline_3_DE
		add a,43
		jp Inflate_DecodeDistance_SetLength
CopyLen17Len:	equ $ - CopyLen17

CopyLen18:	call Reader_ReadBitsInline_3_DE
		add a,51
		jp Inflate_DecodeDistance_SetLength
CopyLen18Len:	equ $ - CopyLen18

CopyLen19:	call Reader_ReadBitsInline_3_DE
		add a,59
		jp Inflate_DecodeDistance_SetLength
CopyLen19Len:	equ $ - CopyLen19

CopyLen20:	call Reader_ReadBitsInline_4_DE
		add a,67
		jp Inflate_DecodeDistance_SetLength
CopyLen20Len:	equ $ - CopyLen20

CopyLen21:	call Reader_ReadBitsInline_4_DE
		add a,83
		jp Inflate_DecodeDistance_SetLength
CopyLen21Len:	equ $ - CopyLen21

CopyLen22:	call Reader_ReadBitsInline_4_DE
		add a,99
		jp Inflate_DecodeDistance_SetLength
CopyLen22Len:	equ $ - CopyLen22

CopyLen23:	call Reader_ReadBitsInline_4_DE
		add a,115
		jp Inflate_DecodeDistance_SetLength
CopyLen23Len:	equ $ - CopyLen23

CopyLen24:	call Reader_ReadBitsInline_5_DE
		add a,131
		jp Inflate_DecodeDistance_SetLength
CopyLen24Len:	equ $ - CopyLen24

CopyLen25:	call Reader_ReadBitsInline_5_DE
		add a,163
		jp Inflate_DecodeDistance_SetLength
CopyLen25Len:	equ $ - CopyLen25

CopyLen26:	call Reader_ReadBitsInline_5_DE
		add a,195
		jp Inflate_DecodeDistance_SetLength
CopyLen26Len:	equ $ - CopyLen26

CopyLen27:	call Reader_ReadBitsInline_5_DE
		add a,227
		exx
		ld c,a
		jp nc,Inflate_DecodeDistance_SetLength_0
		ld b,1
		exx
		jp DistanceTree
CopyLen27Len:	equ $ - CopyLen27

CopyLen28:	exx
		ld bc,258
		exx
		jp DistanceTree
CopyLen28Len:	equ $ - CopyLen28

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

; inline-able version
ThrowInline:	jp ThrowException
ThrowInlineLen:	equ $ - ThrowInline

;
Inflate_literalLengthSymbols:
	db WriteLitLen00
	dw WriteLit00
	db WriteLitLen
	dw WriteLit01
	db WriteLitLen
	dw WriteLit02
	db WriteLitLen
	dw WriteLit03
	db WriteLitLen
	dw WriteLit04
	db WriteLitLen
	dw WriteLit05
	db WriteLitLen
	dw WriteLit06
	db WriteLitLen
	dw WriteLit07
	db WriteLitLen
	dw WriteLit08
	db WriteLitLen
	dw WriteLit09
	db WriteLitLen
	dw WriteLit0A
	db WriteLitLen
	dw WriteLit0B
	db WriteLitLen
	dw WriteLit0C
	db WriteLitLen
	dw WriteLit0D
	db WriteLitLen
	dw WriteLit0E
	db WriteLitLen
	dw WriteLit0F
	db WriteLitLen
	dw WriteLit10
	db WriteLitLen
	dw WriteLit11
	db WriteLitLen
	dw WriteLit12
	db WriteLitLen
	dw WriteLit13
	db WriteLitLen
	dw WriteLit14
	db WriteLitLen
	dw WriteLit15
	db WriteLitLen
	dw WriteLit16
	db WriteLitLen
	dw WriteLit17
	db WriteLitLen
	dw WriteLit18
	db WriteLitLen
	dw WriteLit19
	db WriteLitLen
	dw WriteLit1A
	db WriteLitLen
	dw WriteLit1B
	db WriteLitLen
	dw WriteLit1C
	db WriteLitLen
	dw WriteLit1D
	db WriteLitLen
	dw WriteLit1E
	db WriteLitLen
	dw WriteLit1F
	db WriteLitLen
	dw WriteLit20
	db WriteLitLen
	dw WriteLit21
	db WriteLitLen
	dw WriteLit22
	db WriteLitLen
	dw WriteLit23
	db WriteLitLen
	dw WriteLit24
	db WriteLitLen
	dw WriteLit25
	db WriteLitLen
	dw WriteLit26
	db WriteLitLen
	dw WriteLit27
	db WriteLitLen
	dw WriteLit28
	db WriteLitLen
	dw WriteLit29
	db WriteLitLen
	dw WriteLit2A
	db WriteLitLen
	dw WriteLit2B
	db WriteLitLen
	dw WriteLit2C
	db WriteLitLen
	dw WriteLit2D
	db WriteLitLen
	dw WriteLit2E
	db WriteLitLen
	dw WriteLit2F
	db WriteLitLen
	dw WriteLit30
	db WriteLitLen
	dw WriteLit31
	db WriteLitLen
	dw WriteLit32
	db WriteLitLen
	dw WriteLit33
	db WriteLitLen
	dw WriteLit34
	db WriteLitLen
	dw WriteLit35
	db WriteLitLen
	dw WriteLit36
	db WriteLitLen
	dw WriteLit37
	db WriteLitLen
	dw WriteLit38
	db WriteLitLen
	dw WriteLit39
	db WriteLitLen
	dw WriteLit3A
	db WriteLitLen
	dw WriteLit3B
	db WriteLitLen
	dw WriteLit3C
	db WriteLitLen
	dw WriteLit3D
	db WriteLitLen
	dw WriteLit3E
	db WriteLitLen
	dw WriteLit3F
	db WriteLitLen
	dw WriteLit40
	db WriteLitLen
	dw WriteLit41
	db WriteLitLen
	dw WriteLit42
	db WriteLitLen
	dw WriteLit43
	db WriteLitLen
	dw WriteLit44
	db WriteLitLen
	dw WriteLit45
	db WriteLitLen
	dw WriteLit46
	db WriteLitLen
	dw WriteLit47
	db WriteLitLen
	dw WriteLit48
	db WriteLitLen
	dw WriteLit49
	db WriteLitLen
	dw WriteLit4A
	db WriteLitLen
	dw WriteLit4B
	db WriteLitLen
	dw WriteLit4C
	db WriteLitLen
	dw WriteLit4D
	db WriteLitLen
	dw WriteLit4E
	db WriteLitLen
	dw WriteLit4F
	db WriteLitLen
	dw WriteLit50
	db WriteLitLen
	dw WriteLit51
	db WriteLitLen
	dw WriteLit52
	db WriteLitLen
	dw WriteLit53
	db WriteLitLen
	dw WriteLit54
	db WriteLitLen
	dw WriteLit55
	db WriteLitLen
	dw WriteLit56
	db WriteLitLen
	dw WriteLit57
	db WriteLitLen
	dw WriteLit58
	db WriteLitLen
	dw WriteLit59
	db WriteLitLen
	dw WriteLit5A
	db WriteLitLen
	dw WriteLit5B
	db WriteLitLen
	dw WriteLit5C
	db WriteLitLen
	dw WriteLit5D
	db WriteLitLen
	dw WriteLit5E
	db WriteLitLen
	dw WriteLit5F
	db WriteLitLen
	dw WriteLit60
	db WriteLitLen
	dw WriteLit61
	db WriteLitLen
	dw WriteLit62
	db WriteLitLen
	dw WriteLit63
	db WriteLitLen
	dw WriteLit64
	db WriteLitLen
	dw WriteLit65
	db WriteLitLen
	dw WriteLit66
	db WriteLitLen
	dw WriteLit67
	db WriteLitLen
	dw WriteLit68
	db WriteLitLen
	dw WriteLit69
	db WriteLitLen
	dw WriteLit6A
	db WriteLitLen
	dw WriteLit6B
	db WriteLitLen
	dw WriteLit6C
	db WriteLitLen
	dw WriteLit6D
	db WriteLitLen
	dw WriteLit6E
	db WriteLitLen
	dw WriteLit6F
	db WriteLitLen
	dw WriteLit70
	db WriteLitLen
	dw WriteLit71
	db WriteLitLen
	dw WriteLit72
	db WriteLitLen
	dw WriteLit73
	db WriteLitLen
	dw WriteLit74
	db WriteLitLen
	dw WriteLit75
	db WriteLitLen
	dw WriteLit76
	db WriteLitLen
	dw WriteLit77
	db WriteLitLen
	dw WriteLit78
	db WriteLitLen
	dw WriteLit79
	db WriteLitLen
	dw WriteLit7A
	db WriteLitLen
	dw WriteLit7B
	db WriteLitLen
	dw WriteLit7C
	db WriteLitLen
	dw WriteLit7D
	db WriteLitLen
	dw WriteLit7E
	db WriteLitLen
	dw WriteLit7F
	db WriteLitLen
	dw WriteLit80
	db WriteLitLen
	dw WriteLit81
	db WriteLitLen
	dw WriteLit82
	db WriteLitLen
	dw WriteLit83
	db WriteLitLen
	dw WriteLit84
	db WriteLitLen
	dw WriteLit85
	db WriteLitLen
	dw WriteLit86
	db WriteLitLen
	dw WriteLit87
	db WriteLitLen
	dw WriteLit88
	db WriteLitLen
	dw WriteLit89
	db WriteLitLen
	dw WriteLit8A
	db WriteLitLen
	dw WriteLit8B
	db WriteLitLen
	dw WriteLit8C
	db WriteLitLen
	dw WriteLit8D
	db WriteLitLen
	dw WriteLit8E
	db WriteLitLen
	dw WriteLit8F
	db WriteLitLen
	dw WriteLit90
	db WriteLitLen
	dw WriteLit91
	db WriteLitLen
	dw WriteLit92
	db WriteLitLen
	dw WriteLit93
	db WriteLitLen
	dw WriteLit94
	db WriteLitLen
	dw WriteLit95
	db WriteLitLen
	dw WriteLit96
	db WriteLitLen
	dw WriteLit97
	db WriteLitLen
	dw WriteLit98
	db WriteLitLen
	dw WriteLit99
	db WriteLitLen
	dw WriteLit9A
	db WriteLitLen
	dw WriteLit9B
	db WriteLitLen
	dw WriteLit9C
	db WriteLitLen
	dw WriteLit9D
	db WriteLitLen
	dw WriteLit9E
	db WriteLitLen
	dw WriteLit9F
	db WriteLitLen
	dw WriteLitA0
	db WriteLitLen
	dw WriteLitA1
	db WriteLitLen
	dw WriteLitA2
	db WriteLitLen
	dw WriteLitA3
	db WriteLitLen
	dw WriteLitA4
	db WriteLitLen
	dw WriteLitA5
	db WriteLitLen
	dw WriteLitA6
	db WriteLitLen
	dw WriteLitA7
	db WriteLitLen
	dw WriteLitA8
	db WriteLitLen
	dw WriteLitA9
	db WriteLitLen
	dw WriteLitAA
	db WriteLitLen
	dw WriteLitAB
	db WriteLitLen
	dw WriteLitAC
	db WriteLitLen
	dw WriteLitAD
	db WriteLitLen
	dw WriteLitAE
	db WriteLitLen
	dw WriteLitAF
	db WriteLitLen
	dw WriteLitB0
	db WriteLitLen
	dw WriteLitB1
	db WriteLitLen
	dw WriteLitB2
	db WriteLitLen
	dw WriteLitB3
	db WriteLitLen
	dw WriteLitB4
	db WriteLitLen
	dw WriteLitB5
	db WriteLitLen
	dw WriteLitB6
	db WriteLitLen
	dw WriteLitB7
	db WriteLitLen
	dw WriteLitB8
	db WriteLitLen
	dw WriteLitB9
	db WriteLitLen
	dw WriteLitBA
	db WriteLitLen
	dw WriteLitBB
	db WriteLitLen
	dw WriteLitBC
	db WriteLitLen
	dw WriteLitBD
	db WriteLitLen
	dw WriteLitBE
	db WriteLitLen
	dw WriteLitBF
	db WriteLitLen
	dw WriteLitC0
	db WriteLitLen
	dw WriteLitC1
	db WriteLitLen
	dw WriteLitC2
	db WriteLitLen
	dw WriteLitC3
	db WriteLitLen
	dw WriteLitC4
	db WriteLitLen
	dw WriteLitC5
	db WriteLitLen
	dw WriteLitC6
	db WriteLitLen
	dw WriteLitC7
	db WriteLitLen
	dw WriteLitC8
	db WriteLitLen
	dw WriteLitC9
	db WriteLitLen
	dw WriteLitCA
	db WriteLitLen
	dw WriteLitCB
	db WriteLitLen
	dw WriteLitCC
	db WriteLitLen
	dw WriteLitCD
	db WriteLitLen
	dw WriteLitCE
	db WriteLitLen
	dw WriteLitCF
	db WriteLitLen
	dw WriteLitD0
	db WriteLitLen
	dw WriteLitD1
	db WriteLitLen
	dw WriteLitD2
	db WriteLitLen
	dw WriteLitD3
	db WriteLitLen
	dw WriteLitD4
	db WriteLitLen
	dw WriteLitD5
	db WriteLitLen
	dw WriteLitD6
	db WriteLitLen
	dw WriteLitD7
	db WriteLitLen
	dw WriteLitD8
	db WriteLitLen
	dw WriteLitD9
	db WriteLitLen
	dw WriteLitDA
	db WriteLitLen
	dw WriteLitDB
	db WriteLitLen
	dw WriteLitDC
	db WriteLitLen
	dw WriteLitDD
	db WriteLitLen
	dw WriteLitDE
	db WriteLitLen
	dw WriteLitDF
	db WriteLitLen
	dw WriteLitE0
	db WriteLitLen
	dw WriteLitE1
	db WriteLitLen
	dw WriteLitE2
	db WriteLitLen
	dw WriteLitE3
	db WriteLitLen
	dw WriteLitE4
	db WriteLitLen
	dw WriteLitE5
	db WriteLitLen
	dw WriteLitE6
	db WriteLitLen
	dw WriteLitE7
	db WriteLitLen
	dw WriteLitE8
	db WriteLitLen
	dw WriteLitE9
	db WriteLitLen
	dw WriteLitEA
	db WriteLitLen
	dw WriteLitEB
	db WriteLitLen
	dw WriteLitEC
	db WriteLitLen
	dw WriteLitED
	db WriteLitLen
	dw WriteLitEE
	db WriteLitLen
	dw WriteLitEF
	db WriteLitLen
	dw WriteLitF0
	db WriteLitLen
	dw WriteLitF1
	db WriteLitLen
	dw WriteLitF2
	db WriteLitLen
	dw WriteLitF3
	db WriteLitLen
	dw WriteLitF4
	db WriteLitLen
	dw WriteLitF5
	db WriteLitLen
	dw WriteLitF6
	db WriteLitLen
	dw WriteLitF7
	db WriteLitLen
	dw WriteLitF8
	db WriteLitLen
	dw WriteLitF9
	db WriteLitLen
	dw WriteLitFA
	db WriteLitLen
	dw WriteLitFB
	db WriteLitLen
	dw WriteLitFC
	db WriteLitLen
	dw WriteLitFD
	db WriteLitLen
	dw WriteLitFE
	db WriteLitLen
	dw WriteLitFF

	db EndBlockLen
	dw EndBlock

	db CopyLen0Len
	dw CopyLen0
	db CopyLen1Len
	dw CopyLen1
	db CopyLen2Len
	dw CopyLen2
	db CopyLen3Len
	dw CopyLen3
	db CopyLen4Len
	dw CopyLen4
	db CopyLen5Len
	dw CopyLen5
	db CopyLen6Len
	dw CopyLen6
	db CopyLen7Len
	dw CopyLen7
	db CopyLen8Len
	dw CopyLen8
	db CopyLen9Len
	dw CopyLen9
	db CopyLen10Len
	dw CopyLen10
	db CopyLen11Len
	dw CopyLen11
	db CopyLen12Len
	dw CopyLen12
	db CopyLen13Len
	dw CopyLen13
	db CopyLen14Len
	dw CopyLen14
	db CopyLen15Len
	dw CopyLen15
	db CopyLen16Len
	dw CopyLen16
	db CopyLen17Len
	dw CopyLen17
	db CopyLen18Len
	dw CopyLen18
	db CopyLen19Len
	dw CopyLen19
	db CopyLen20Len
	dw CopyLen20
	db CopyLen21Len
	dw CopyLen21
	db CopyLen22Len
	dw CopyLen22
	db CopyLen23Len
	dw CopyLen23
	db CopyLen24Len
	dw CopyLen24
	db CopyLen25Len
	dw CopyLen25
	db CopyLen26Len
	dw CopyLen26
	db CopyLen27Len
	dw CopyLen27
	db CopyLen28Len
	dw CopyLen28
	db ThrowInlineLen
	dw ThrowInline
	db ThrowInlineLen
	dw ThrowInline

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
