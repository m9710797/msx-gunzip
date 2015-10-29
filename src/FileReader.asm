;
; Buffered sequential-access file reader
;
FileReader: MACRO
	super: Reader
	fileHandle:
		db 0FFH
	_size:
	ENDM

FileReader_class: Class FileReader, FileReader_template, Heap_main
FileReader_template: FileReader

; de = file path
; hl = buffer start
; bc = buffer size
; ix = this
; ix <- this
; de <- this
FileReader_Construct:
	push de
	call Reader_Construct
	pop de
	ld a,00000001B  ; read only
	call DOS_OpenFileHandle
	call Application_CheckDOSError
	ld (ix + FileReader.fileHandle),b
	ld (ix + FileReader.super.filler),FileReader_ReadFromFile & 0FFH
	ld (ix + FileReader.super.filler + 1),FileReader_ReadFromFile >> 8
	call FileReader_ReadFromFile
	ld e,ixl
	ld d,ixh
	ret

; ix = this
; ix <- this
FileReader_Destruct:
	ld b,(ix + FileReader.fileHandle)
	call DOS_CloseFileHandle
	call Application_CheckDOSError
	call Reader_Destruct
	ret

; ix = this
; Modifies: af, bc, de, hl
FileReader_ReadFromFile: PROC
	call DOS_ConsoleStatus  ; allow ctrl-c
	ld b,(ix + FileReader.fileHandle)
	ld e,(ix + FileReader.super.bufferStart)
	ld d,(ix + FileReader.super.bufferStart + 1)
	ld l,(ix + FileReader.super.bufferEnd)
	ld h,(ix + FileReader.super.bufferEnd + 1)
	and a
	sbc hl,de
	call DOS_ReadFromFileHandle
	cp .EOF
	jp z,EndOfFile
	call Application_CheckDOSError
	ret
EndOfFile:
	call Reader_MarkEndOfData
	ret
	ENDP
