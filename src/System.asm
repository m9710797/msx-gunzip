;
; System routines
;

; hl = value
System_PrintHexHL:
	ld a,h
	push hl
	call System_PrintHexA
	pop hl
	ld a,l
	;jr System_PrintHexA

; a = value
System_PrintHexA:
	push af
	rrca
	rrca
	rrca
	rrca
	call System_PrintHex
	pop af
	;jr System_PrintHex

; a = value (0 - 15)
System_PrintHex:
	and 0FH
	cp 10
	ccf
	adc a,"0"
	daa
	;jr System_PrintChar

; a = character
System_PrintChar:
	ld iy,(EXPTBL-1)
	ld ix,CHPUT
	jp CALSLT

; hl = string (0-terminated)
System_PrintLn:
	call System_Print
System_PrintCrLf:
	ld hl,System_crlf
	;jr System_Print

; hl = string (0-terminated)
; Modifies: none
System_Print:
	ld a,(hl)
	inc hl
	and a
	ret z
	push hl
	call System_PrintChar
	pop hl
	jr System_Print

System_ThrowException_:
	jp System_ThrowException
System_ThrowException:
	IF DEBUG
	in a,(02EH)
	ENDIF
	pop de
	call System_PrintExceptionMessage
	jp DOS_Terminate

; hl = message
System_ThrowExceptionWithMessage:
	IF DEBUG
	in a,(02EH)
	ENDIF
	pop de
	push hl
	call System_PrintExceptionMessage
	pop hl
	call System_PrintLn
	jp DOS_Terminate

; de = address
System_PrintExceptionMessage:
	push de
	ld hl,System_exceptionMessage
	call System_Print
	pop hl
	dec hl
	dec hl
	dec hl
	call System_PrintHexHL
	jr System_PrintCrLf


System_exceptionMessage:
	db "An exception occurred on address: ", 0

System_crlf:
	db "\r\n", 0
