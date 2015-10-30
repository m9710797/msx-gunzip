;
; Pads up to the next multiple of the specified address.
;
ALIGN: MACRO ?boundary
	ds ?boundary - 1 - ($ + ?boundary - 1) % ?boundary
	ENDM

VIRTUAL_ALIGN: MACRO ?boundary
	ds VIRTUAL ?boundary - 1 - ($ + ?boundary - 1) % ?boundary
	ENDM
