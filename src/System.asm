;
; System routines
;

; a = character
; Modifies: none
System_PrintChar:
	exx
	ex af,af'
	push af
	push bc
	push de
	push hl
	ex af,af'
	exx
	push ix
	push iy
	ld iy,(EXPTBL-1)
	ld ix,CHPUT
	call CALSLT
	ei
	pop iy
	pop ix
	exx
	ex af,af'
	pop hl
	pop de
	pop bc
	pop af
	ex af,af'
	exx
	ret

; hl = string (0-terminated)
; Modifies: none
System_Print:
	push af
	push hl
System_Print_Loop:
	ld a,(hl)
	and a
	jp z,System_Print_Done
	call System_PrintChar
	inc hl
	jp System_Print_Loop
System_Print_Done:
	pop hl
	pop af
	ret

; hl = string (0-terminated)
; Modifies: none
System_PrintLn:
	call System_Print
	push hl
	ld hl,System_crlf
	call System_Print
	pop hl
	ret

; hl = value
; Modifies: none
System_PrintHexHL:
	push af
	ld a,h
	call System_PrintHexA
	ld a,l
	call System_PrintHexA
	pop af
	ret

; a = value
; Modifies: none
System_PrintHexA:
	push af
	rrca
	rrca
	rrca
	rrca
	and 0FH
	call System_PrintHex
	pop af
	and 0FH
	call System_PrintHex
	ret

; a = value (0 - 15)
; Modifies: none
System_PrintHex:
	push af
	call System_NibbleToHexDigit
	call System_PrintChar
	pop af
	ret

; a = value (0 - 15)
; a <- hexadecimal character
; Modifies: a
System_NibbleToHexDigit:
	cp 10
	ccf
	adc a,"0"
	daa
	ret

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
	ld hl,System_crlf
	jp System_Print

;
System_exceptionMessage:
	db "An exception occurred on address: ", 0

System_crlf:
	db "\r\n", 0
