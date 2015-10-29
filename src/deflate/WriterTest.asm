;
; Writer unit tests
;
WriterTest_Test:
	call WriterTest_TestCount
	call WriterTest_TestCRC32
	ret

WriterTest_TestCount: PROC
	ld hl,OBUFFER
	ld bc,256
	call NullWriter_class.New
	call NullWriter_Construct
	push ix
	pop iy

	call Writer_GetCount
	ld a,l
	or h
	or e
	or d
	call nz,System_ThrowException

	ld b,58
Loop1:
	call Writer_Write_IY
	djnz Loop1
	call Writer_GetCount
	ld bc,58
	and a
	sbc hl,bc
	call nz,System_ThrowException
	ld a,e
	or d
	call nz,System_ThrowException

	ld b,200
Loop2:
	call Writer_Write_IY
	djnz Loop2
	call Writer_GetCount
	ld bc,258
	and a
	sbc hl,bc
	call nz,System_ThrowException
	ld a,e
	or d
	call nz,System_ThrowException

	call NullWriter_Destruct
	call NullWriter_class.Delete
	ret
	ENDP

WriterTest_TestCRC32: PROC
	ld hl,OBUFFER
	ld bc,256
	call NullWriter_class.New
	call NullWriter_Construct
	push ix
	pop iy

	call Writer_GetCRC32
	ld a,e
	and d
	and c
	and b
	inc a
	call nz,System_ThrowException

	ld b,58
Loop1:
	ld a,b
	call Writer_Write_IY
	djnz Loop1
	call Writer_GetCRC32
	ld hl,07364H
	scf
	adc hl,de
	call nz,System_ThrowException
	ld hl,0DAA8H
	scf
	adc hl,bc
	call nz,System_ThrowException

	ld b,200
Loop2:
	ld a,b
	call Writer_Write_IY
	djnz Loop2
	call Writer_GetCRC32
	ld hl,04E96H
	scf
	adc hl,de
	call nz,System_ThrowException
	ld hl,02DA9H
	scf
	adc hl,bc
	call nz,System_ThrowException

	call NullWriter_Destruct
	call NullWriter_class.Delete
	ret
	ENDP
