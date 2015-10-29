;
; Gzip archive
;
Archive_FTEXT: equ 1 << 0;
Archive_FHCRC: equ 1 << 1;
Archive_FEXTRA: equ 1 << 2;
Archive_FNAME: equ 1 << 3;
Archive_FCOMMENT: equ 1 << 4;
Archive_RESERVED: equ 1 << 5 | 1 << 6 | 1 << 7;

Archive: MACRO
	reader:
		dw 0
	writer:
		dw 0
	inflate:
		dw 0
	flags:
		db 0
	mtime:
		dd 0
	xfl:
		db 0
	os:
		db 0
	isize:
		dd 0
	crc32:
		dd 0
	_size:
	ENDM

Archive_class: Class Archive, Archive_template, Heap_main
Archive_template: Archive

; hl = buffer reader
; de = buffer writer (min 32K)
; ix = this
; ix <- this
; de <- this
Archive_Construct:
	ld iyl,e  ; check if write buffer is at least 32K
	ld iyh,d
	ld a,(iy + Writer.bufferSize + 1)
	cp 80H
	call c,System_ThrowException
	ld (ix + Archive.reader),l
	ld (ix + Archive.reader + 1),h
	ld (ix + Archive.writer),e
	ld (ix + Archive.writer + 1),d
	push ix
	call Inflate_class.New
	call Inflate_Construct
	pop ix
	ld (ix + Archive.inflate),e
	ld (ix + Archive.inflate + 1),d
	ld e,ixl
	ld d,ixh
	ret

; ix = this
; ix <- this
Archive_Destruct:
	push ix
	call Archive_GetInflate
	call Inflate_Destruct
	call Inflate_class.Delete
	pop ix
	ret

; ix = this
; de <- file reader
; ix <- file reader
Archive_GetReader:
	ld e,(ix + Archive.reader)
	ld d,(ix + Archive.reader + 1)
	ld ixl,e
	ld ixh,d
	ret

; ix = this
; de <- file writer
; ix <- file writer
Archive_GetWriter:
	ld e,(ix + Archive.writer)
	ld d,(ix + Archive.writer + 1)
	ld ixl,e
	ld ixh,d
	ret

; ix = this
; de <- Inflate implementation
; ix <- Inflate implementation
Archive_GetInflate:
	ld e,(ix + Archive.inflate)
	ld d,(ix + Archive.inflate + 1)
	ld ixl,e
	ld ixh,d
	ret

; ix = this
; a <- value
; Modifies: de
Archive_Read:
	push ix
	call Archive_GetReader
	call Reader_Read
	pop ix
	ret

; ix = this
Archive_Extract:
	call Archive_ReadHeader
	call Archive_Inflate
	call Archive_Verify
	ret

; ix = this
Archive_ReadHeader:
	call Archive_Read
	cp 31  ; gzip signature (1)
	ld hl,Archive_notGzipError
	jp nz,Application_TerminateWithError
	call Archive_Read
	cp 139  ; gzip signature (1)
	ld hl,Archive_notGzipError
	jp nz,Application_TerminateWithError
	call Archive_Read
	cp 8  ; deflate compression ID (1)
	ld hl,Archive_notDeflateError
	jp nz,Application_TerminateWithError

	call Archive_Read
	ld (ix + Archive.flags),a
	call Archive_Read
	ld (ix + Archive.mtime),a
	call Archive_Read
	ld (ix + Archive.mtime + 1),a
	call Archive_Read
	ld (ix + Archive.mtime + 2),a
	call Archive_Read
	ld (ix + Archive.mtime + 3),a
	call Archive_Read
	ld (ix + Archive.xfl),a
	call Archive_Read
	ld (ix + Archive.os),a

	ld a,(ix + Archive.flags)
	and Archive_RESERVED
	ld hl,Archive_unknownFlagError
	jp nz,Application_TerminateWithError

	ld a,(ix + Archive.flags)
	and Archive_FEXTRA
	call nz,Archive_SkipExtra

	ld a,(ix + Archive.flags)
	and Archive_FNAME
	call nz,Archive_SkipName

	ld a,(ix + Archive.flags)
	and Archive_FCOMMENT
	call nz,Archive_SkipComment

	ld a,(ix + Archive.flags)
	and Archive_FHCRC
	call nz,Archive_SkipHeaderCRC
	ret

; ix = this
Archive_Inflate:
	push ix
	call Archive_GetInflate
	call Inflate_Inflate
	pop ix
	ret

; ix = this
Archive_Verify:
	call Archive_Read
	ld (ix + Archive.crc32),a
	call Archive_Read
	ld (ix + Archive.crc32 + 1),a
	call Archive_Read
	ld (ix + Archive.crc32 + 2),a
	call Archive_Read
	ld (ix + Archive.crc32 + 3),a
	call Archive_Read
	ld (ix + Archive.isize),a
	call Archive_Read
	ld (ix + Archive.isize + 1),a
	call Archive_Read
	ld (ix + Archive.isize + 2),a
	call Archive_Read
	ld (ix + Archive.isize + 3),a

	call Archive_VerifyISIZE
	ld hl,Archive_isizeMismatchError
	call nz,Application_TerminateWithError

	call Archive_VerifyCRC32
	ld hl,Archive_crc32MismatchError
	call nz,Application_TerminateWithError
	ret

; ix = this
Archive_SkipExtra:
	call Archive_Read
	ld c,a
	call Archive_Read
	ld b,a
	push ix
	call Archive_GetReader
	call Reader_Skip
	pop ix
	ret

; ix = this
Archive_SkipName:
	call Archive_Read
	and a
	jp nz,Archive_SkipName
	ret

; ix = this
Archive_SkipComment:
	call Archive_Read
	and a
	jp nz,Archive_SkipComment
	ret

; ix = this
Archive_SkipHeaderCRC:
	call Archive_Read
	call Archive_Read
	ret

; ix = this
; f <- nz: mismatch
Archive_VerifyISIZE:
	push ix
	call Archive_GetWriter
	call Writer_GetCount
	pop ix
	ld a,l
	cp (ix + Archive.isize)
	ret nz
	ld a,h
	cp (ix + Archive.isize + 1)
	ret nz
	ld a,e
	cp (ix + Archive.isize + 2)
	ret nz
	ld a,d
	cp (ix + Archive.isize + 3)
	ret

; ix = this
; f <- nz: mismatch
Archive_VerifyCRC32:
	push ix
	call Archive_GetWriter
	call Writer_GetCRC32
	pop ix
	ld l,(ix + Archive.crc32)
	ld h,(ix + Archive.crc32 + 1)
	scf
	adc hl,de
	ret nz
	ld l,(ix + Archive.crc32 + 2)
	ld h,(ix + Archive.crc32 + 3)
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
