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

; Modifies: none
System_PrintCrLf:
	push hl
	ld hl,System_crlf
	call System_Print
	pop hl
	ret

; dehl = value
; Modifies: none
System_PrintHexDEHL:
	ex de,hl
	call System_PrintHexHL
	ex de,hl
	call System_PrintHexHL
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

; a = value
; Modifies: none
System_PrintHexANoLeading0:
	push af
	rrca
	rrca
	rrca
	rrca
	and 0FH
	call nz,System_PrintHex
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

; a = value
; Modifies: none
System_PrintDecA:
	push hl
	ld l,a
	ld h,0
	call System_PrintDecHL
	pop hl
	ret

; hl = value
; Modifies: none
System_PrintDecHL:
	push de
	ld de,0
	call System_PrintDecDEHL
	pop de
	ret

; dehl = value
; Modifies: none
System_PrintDecDEHL: PROC
	push af
	push bc
	push de
	push hl
	push iy
	ex de,hl
	ld iyl,e
	ld iyh,d
	ld a,80H
	ld bc,-1000000000 >> 16
	ld de,-1000000000 & 0FFFFH
	call Digit
	ld bc,100000000 >> 16
	ld de,100000000 & 0FFFFH
	call DigitReverse
	ld bc,-10000000 >> 16
	ld de,-10000000 & 0FFFFH
	call Digit
	ld bc,1000000 >> 16
	ld de,1000000 & 0FFFFH
	call DigitReverse
	ld bc,-100000 >> 16
	ld de,-100000 & 0FFFFH
	call Digit
	ld bc,10000 >> 16
	ld de,10000 & 0FFFFH
	call DigitReverse
	ld bc,-1000 >> 16
	ld de,-1000 & 0FFFFH
	call Digit
	ld bc,100 >> 16
	ld de,100 & 0FFFFH
	call DigitReverse
	ld bc,-10 >> 16
	ld de,-10 & 0FFFFH
	call Digit
	ld bc,1 >> 16
	ld de,1 & 0FFFFH
	and 7FH
	call DigitReverse
	pop iy
	pop hl
	pop de
	pop bc
	pop af
	ret
Digit:
	and 80H
	or "0" - 1
Loop:
	inc a
	add iy,de
	adc hl,bc
	jp c,Loop
	jp Print
DigitReverse:
	and 80H
	or "9" + 1
LoopReverse:
	dec a
	add iy,de
	adc hl,bc
	jp nc,LoopReverse
	jp Print
Print:
	and a
	jp p,System_PrintChar
	cp "0" + 80H
	ret z
	and 7FH
	jp System_PrintChar
	ENDP

; de = ASCIIZ string
; a <- length, excluding the terminator
; bc <- 0 - length, excluding the terminator
; hl <- end of ASCIIZ string + 1
; Modifies: af, bc, hl
System_GetStringLength:
	ex de,hl
	ld e,l
	ld d,h
	xor a
	ld b,a
	ld c,a
	cpir
	ld a,c
	inc bc
	cpl
	ret

	SECTION RAM

; Up to 19% faster alternative for large LDIRs (break-even at 21 loops)
; hl = source
; de = destination
; bc = byte count
System_FastLDIR: PROC
	xor a
	sub c
	and 16-1
	add a,a
	di
	ld (jumpOffset),a
	ei
	jr nz,$
jumpOffset: equ $ - 1
Loop:
	REPT 16
	ldi
	ENDM
	jp pe,Loop
	ret
	ENDP

	ENDS

System_EnableTurbo:
	call System_IsTurboR
	ret c
	ld a,10000001B
	ld iy,(EXPTBL-1)
	ld ix,CHGCPU
	call CALSLT
	ei
	ret

System_DisableTurbo:
	call System_IsTurboR
	ret c
	ld a,10000000B
	ld iy,(EXPTBL-1)
	ld ix,CHGCPU
	call CALSLT
	ei
	ret

; f <- c: not turbo R
System_IsTurboR:
	ld a,(EXPTBL)
	ld hl,IDBYT2
	call RDSLT
	ei
	cp 3
	ret

; hl <- current timer value, in 14 cycle increments
; Modifies: af, hl
System_GetHighResTimerValue:
	in a,(0E7H)
	ld h,a
	in a,(0E6H)
	ld l,a
	and a
	ret m
	in a,(0E7H)
	ld h,a
	ret

System_Stop:
	di
	halt
	jp System_Stop

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
	call System_Print
	ret

;
System_exceptionMessage:
	db "An exception occurred on address: ", 0

System_crlf:
	db "\r\n", 0
