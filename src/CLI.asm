;
; Command-line interface parser
;

cli_archivePath:
	dw 0
cli_outputPath:
	dw 0
cli_quiet:
	db 0
cli_buffer:
	ds 255


ParseCLI: PROC
	ld de,cli_buffer
	ld hl,CLI_parametersEnvName
	ld b,255
	call DOS_GetEnvironmentItem

	ld de,cli_buffer
Loop:
	ld a,(de)
	and a
	ret z
	cp "/"
	jr z,Option
	cp " "
	jr nz,Path
Next:	inc de
	jr Loop

Option:
	inc de
	ld a,(de)
	and 11011111B  ; upper-case
	cp "Q"
	jr z,OptionQuiet
	ld hl,CLI_unknownOptionError
	jp Application_TerminateWithError

OptionQuiet:
	ld (cli_quiet),a	; any non-zero value
	inc de
	ld a,(de)
	and a
	ret z
	cp " "
	jr z,Next
	ld hl,CLI_unknownOptionError
	jp Application_TerminateWithError

Path:
	ld hl,(cli_archivePath)
	ld a,h
	or l
	jr nz,OutputPath
	ld (cli_archivePath),de
ParsePath:
	call DOS_ParsePathname
	ld a,(de)
	and a
	ret z
	xor a
	ld (de),a
	jr Next

OutputPath:
	ld hl,(cli_outputPath)
	ld a,h
	or l
	ld hl,CLI_multiplePathsError
	call nz,Application_TerminateWithError
	ld (cli_outputPath),de
	jp ParsePath

	ENDP


CLI_parametersEnvName:
	db "PARAMETERS",0

CLI_unknownOptionError:
	db "Unknown command line option.",13,10,0

CLI_multiplePathsError:
	db "Can not specify additional file paths.",13,10,0
