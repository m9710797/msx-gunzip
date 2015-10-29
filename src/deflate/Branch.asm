;
; Huffman tree node
;
Branch_ID: equ 0CBH  ; First byte of a branch object, for ID purposes

Branch: MACRO
	; ix = reader
	Process:
		Reader_ReadBitInline
		jp nc,0
	zero: equ $ - 2
		jp 0
	one: equ $ - 2
	_size:
	ENDM

Branch_class: Class Branch, Branch_template, Heap_main
Branch_template: Branch

; ix = this
; ix <- this
; de <- this
Branch_Construct:
	ld e,ixl
	ld d,ixh
	ret

; ix = this
; ix <- this
Branch_Destruct: PROC
	ld e,(ix + Branch.zero)
	ld d,(ix + Branch.zero + 1)
	ld a,e
	or d
	jr z,One
	ld a,(de)
	cp Branch_ID
	jp nz,One
	push ix
	ld ixl,e
	ld ixh,d
	call Branch_Destruct
	call Branch_class.Delete
	pop ix
One:
	ld e,(ix + Branch.one)
	ld d,(ix + Branch.one + 1)
	ld a,e
	or d
	ret z
	ld a,(de)
	cp Branch_ID
	ret nz
	push ix
	ld ixl,e
	ld ixh,d
	call Branch_Destruct
	call Branch_class.Delete
	pop ix
	ret
	ENDP

; b = bit length
; hl = code (left aligned)
; iy = symbol callback
; ix = this
Branch_Build: PROC
	add hl,hl
	jp c,One
Zero:
	ld e,(ix + Branch.zero)
	ld d,(ix + Branch.zero + 1)
	ld a,d
	or e
	djnz ZeroRecurse
	call nz,System_ThrowException
	ld e,iyl
	ld d,iyh
	ld (ix + Branch.zero),e
	ld (ix + Branch.zero + 1),d
	ret
ZeroRecurse:
	jr nz,ZeroExists
	push ix
	call Branch_class.New
	call Branch_Construct
	pop ix
	ld (ix + Branch.zero),e
	ld (ix + Branch.zero + 1),d
ZeroExists:
	ld a,(de)
	cp Branch_ID
	call nz,System_ThrowException
	ld ixl,e
	ld ixh,d
	jp Branch_Build
One:
	ld e,(ix + Branch.one)
	ld d,(ix + Branch.one + 1)
	ld a,d
	or e
	djnz OneRecurse
	call nz,System_ThrowException
	ld e,iyl
	ld d,iyh
	ld (ix + Branch.one),e
	ld (ix + Branch.one + 1),d
	ret
OneRecurse:
	jr nz,OneExists
	push ix
	call Branch_class.New
	call Branch_Construct
	pop ix
	ld (ix + Branch.one),e
	ld (ix + Branch.one + 1),d
OneExists:
	ld a,(de)
	cp Branch_ID
	call nz,System_ThrowException
	ld ixl,e
	ld ixh,d
	jp Branch_Build
	ENDP
