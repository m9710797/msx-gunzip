;
; Buffered sequential-access file writer
;
FileWriter: MACRO
	super: Writer
	fileHandle:
		db 0FFH
	_size:
	ENDM

FileWriter_class: Class FileWriter, FileWriter_template, Heap_main
FileWriter_template: FileWriter

; de = file path
; hl = buffer start
; bc = buffer size
; ix = this
; ix <- this
; de <- this
FileWriter_Construct: PROC
	push de
	call Writer_Construct
	pop de
	ld (ix + FileWriter.fileHandle),0FFH	; invalid file handle
	ld a,d
	or e
	jr z,no_file
	ld a,00000010B  ; write only
	ld b,0
	call DOS_CreateFileHandle
	call Application_CheckDOSError
	ld (ix + FileWriter.fileHandle),b
no_file:	
	ld (ix + FileWriter.super.flusher),FileWriter_WriteToFile & 0FFH
	ld (ix + FileWriter.super.flusher + 1),FileWriter_WriteToFile >> 8
	ld e,ixl
	ld d,ixh
	ret
	ENDP

; ix = this
; ix <- this
FileWriter_Destruct: PROC
	call FileWriter_WriteToFile
	ld b,(ix + FileWriter.fileHandle)
	ld a,b
	inc a
	jr z,no_file
	call DOS_CloseFileHandle
	call Application_CheckDOSError
no_file:
	jp Writer_Destruct
	ENDP

; ix = this
; Modifies: af, bc, de, hl
FileWriter_WriteToFile:
	call DOS_ConsoleStatus  ; allow ctrl-c
	ld b,(ix + FileWriter.fileHandle)
	ld a,b
	inc a
	ret z
	ld e,(ix + FileWriter.super.bufferStart)
	ld d,(ix + FileWriter.super.bufferStart + 1)
	ld l,(ix + FileWriter.super.bufferPosition)
	ld h,(ix + FileWriter.super.bufferPosition + 1)
	and a
	sbc hl,de
	call DOS_WriteToFileHandle
	jp Application_CheckDOSError
