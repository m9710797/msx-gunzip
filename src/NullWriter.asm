;
; Buffered null file writer
;
NullWriter: MACRO
	super: Writer
	fileHandle:
		db 0FFH
	_size:
	ENDM

NullWriter_class: Class NullWriter, NullWriter_template, Heap_main
NullWriter_template: NullWriter

; hl = buffer start
; bc = buffer size
; ix = this
; ix <- this
; de <- this
NullWriter_Construct:
	call Writer_Construct
	ld (ix + FileWriter.super.flusher),NullWriter_Flush & 0FFH
	ld (ix + FileWriter.super.flusher + 1),NullWriter_Flush >> 8
	ret

; ix = this
; ix <- this
NullWriter_Destruct:
	call Writer_Destruct
	ret

; ix = this
NullWriter_Flush:
	call DOS_ConsoleStatus  ; allow ctrl-c
	ret
