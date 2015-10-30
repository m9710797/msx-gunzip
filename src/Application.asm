;
; Top-level application program class
;

Application_Main:
	call DOS_IsDOS2
	ld hl,Application_dos2RequiredError
	jp c,Application_TerminateWithError

	; Check if the stack is well above the heap
	ld hl,-(MEMORY_END + STACK_SIZE)
	add hl,sp
	ld hl,Application_insufficientTPAError
	jp nc,Application_TerminateWithError

	; Parse CLI
	call ParseCLI
	ld hl,(cli_archivePath)
	ld a,l
	or h
	ld hl,Application_usageInstructions
	jp z,Application_TerminateWithError

	; Print Welcome
	ld a,(cli_quiet)
	or a
	ld hl,Application_welcome
	call z,System_Print

	; Print inflating/testing
	ld a,(cli_quiet)
	or a
	jr nz,skip_print
	ld hl,(cli_outputPath)
	ld a,l
	or h
	ld hl,Application_testingFile
	jr z,do_print
	ld hl,Application_inflatingFile
do_print:
	call System_Print
	ld hl,(cli_archivePath)
	call System_Print
	ld hl,Application_dotDotDot
	call System_Print
skip_print:

	; Create FileReader
	ld de,(cli_archivePath)
	call Reader_Construct
	
	; Create FileWriter
	ld de,(cli_outputPath)
	call Writer_Construct

	call Archive_Extract

	call Writer_Destruct
	jp Reader_Destruct


; a <- DOS error code
Application_CheckDOSError:
	and a
	ret z
Application_TerminateWithDOSError:
	ld b,a
	ld de,scratch_buf
	call DOS_ExplainErrorCode
	ld hl,scratch_buf
	call System_PrintLn
	jp DOS_Terminate

; hl <- message
Application_TerminateWithError:
	call System_Print
	jp DOS_Terminate

;
Application_welcome:
	db "Gunzip 1.0 by Grauw",13,10,10,0

Application_inflatingFile:
	db "Inflating ",0

Application_testingFile:
	db "Testing ",0

Application_dotDotDot:
	db "...",13,10,0

Application_dos2RequiredError:
	db "MSX-DOS 2 is required.",13,10,0

Application_insufficientTPAError:
	db "Insufficient TPA space.",13,10,0

Application_usageInstructions:
	db "Usage: gunzip [options] <archive.gz> <outputfile>",13,10
	db 13,10
	db "Options:",13,10
	db "  /q  Quiet mode, suppress messages.",13,10
	db 13,10
	db "If no output file is specified, the archive will be tested.",13,10,0
