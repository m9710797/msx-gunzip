;
; Gzip archive
;
Archive_FTEXT: equ 1 << 0;
Archive_FHCRC: equ 1 << 1;
Archive_FEXTRA: equ 1 << 2;
Archive_FNAME: equ 1 << 3;
Archive_FCOMMENT: equ 1 << 4;
Archive_RESERVED: equ 1 << 5 | 1 << 6 | 1 << 7;

Archive_flags:
	db 0	; TODO not used outside Archive_ReadHeader
Archive_isize:
	dd 0
Archive_crc32:
	dd 0

Archive_Extract:
	; Read header
	ld ix,ReaderObject
	call Reader_Read_IX
	cp 31  ; gzip signature (1)
	ld hl,Archive_notGzipError
	jp nz,Application_TerminateWithError
	call Reader_Read_IX
	cp 139  ; gzip signature (1)
	ld hl,Archive_notGzipError
	jp nz,Application_TerminateWithError
	call Reader_Read_IX
	cp 8  ; deflate compression ID (1)
	ld hl,Archive_notDeflateError
	jp nz,Application_TerminateWithError

	call Reader_Read_IX
	ld (Archive_flags),a
	ld bc,6	; skip mtime[4], xfl, os
	call Reader_Skip_IX

	ld a,(Archive_flags)
	and Archive_RESERVED
	ld hl,Archive_unknownFlagError
	jp nz,Application_TerminateWithError

	ld a,(Archive_flags)
	and Archive_FEXTRA
	jr z,no_skip_extra
	call Reader_Read_IX
	ld c,a
	call Reader_Read_IX
	ld b,a
	call Reader_Skip_IX
no_skip_extra:

	ld a,(Archive_flags)
	and Archive_FNAME
	call nz,Archive_SkipZString

	ld a,(Archive_flags)
	and Archive_FCOMMENT
	call nz,Archive_SkipZString

	ld a,(Archive_flags)
	and Archive_FHCRC
	ld bc,2
	call nz,Reader_Skip_IX

	; actual inflate
	call Inflate_Inflate

	; verify
	ld ix,ReaderObject
	call Reader_Read_IX
	ld (Archive_crc32 + 0),a
	call Reader_Read_IX
	ld (Archive_crc32 + 1),a
	call Reader_Read_IX
	ld (Archive_crc32 + 2),a
	call Reader_Read_IX
	ld (Archive_crc32 + 3),a
	call Reader_Read_IX
	ld (Archive_isize + 0),a
	call Reader_Read_IX
	ld (Archive_isize + 1),a
	call Reader_Read_IX
	ld (Archive_isize + 2),a
	call Reader_Read_IX
	ld (Archive_isize + 3),a

	call Archive_VerifyISIZE
	ld hl,Archive_isizeMismatchError
	jp nz,Application_TerminateWithError

	call Archive_VerifyCRC32
	ld hl,Archive_crc32MismatchError
	jp nz,Application_TerminateWithError
	ret


Archive_SkipZString:
	call Reader_Read_IX
	and a
	jr nz,Archive_SkipZString
	ret


; f <- nz: mismatch
Archive_VerifyISIZE:
	call Writer_GetCount
	ld a,(Archive_isize + 0)
	cp l
	ret nz
	ld a,(Archive_isize + 1)
	cp h
	ret nz
	ld a,(Archive_isize + 2)
	cp e
	ret nz
	ld a,(Archive_isize + 3)
	cp d
	ret

; f <- nz: mismatch
Archive_VerifyCRC32:
	call Writer_GetCRC32
	ld hl,(Archive_crc32 + 0)
	scf
	adc hl,de
	ret nz
	ld hl,(Archive_crc32 + 2)
	scf
	adc hl,bc
	ret

;
Archive_notGzipError:
	db "Not a GZIP file.",13,10,0

Archive_notDeflateError:
	db "Not compressed with DEFLATE.",13,10,0

Archive_unknownFlagError:
	db "Unknown flag.",13,10,0

Archive_isizeMismatchError:
	db "Inflated size mismatch.",13,10,0

Archive_crc32MismatchError:
	db "Inflated CRC32 mismatch.",13,10,0
