;
; Heap unit tests
;
HeapTest_Test:
	ld ix,HeapTest_heap
	call Heap_Construct
	call HeapTest_TestCanAllocate
	call HeapTest_TestAllocationSimple
	call HeapTest_TestAllocationRounding
	call HeapTest_TestAllocationFragmented
	ret

HeapTest_TestCanAllocate:
	; check available space
	ld bc,(HeapTest_heap + Heap.capacity)
	ld ix,HeapTest_heap
	call Heap_CanAllocate
	call nc,System_ThrowException
	ld bc,(HeapTest_heap + Heap.capacity)
	inc bc
	ld ix,HeapTest_heap
	call Heap_CanAllocate
	call c,System_ThrowException
	ret

HeapTest_TestAllocationSimple:
	; allocate entire heap
	ld bc,(HeapTest_heap + Heap.capacity)
	ld ix,HeapTest_heap
	call Heap_Allocate
	ld hl,HeapTest_heapSpace
	and a
	sbc hl,de
	call nz,System_ThrowException
	push bc
	push de
	ld ix,HeapTest_heap
	call Heap_GetFreeSpace
	ld a,b
	or c
	call nz,System_ThrowException
	pop de
	pop bc

	; free allocated space
	ld ix,HeapTest_heap
	call Heap_Free
	ld ix,HeapTest_heap
	call Heap_GetFreeSpace
	and a
	ld hl,(HeapTest_heap + Heap.capacity)
	sbc hl,bc
	call nz,System_ThrowException
	ld bc,(HeapTest_heap + Heap.capacity)
	ld ix,HeapTest_heap
	call Heap_CanAllocate
	call nc,System_ThrowException
	ret

HeapTest_TestAllocationRounding:
	ld bc,1
	ld ix,HeapTest_heap
	call Heap_Allocate
	push bc
	push de
	and a
	ld hl,4
	sbc hl,bc
	call nz,System_ThrowException
	ld ix,HeapTest_heap
	call Heap_GetFreeSpace
	and a
	ld hl,(HeapTest_heap + Heap.capacity)
	ld de,4
	sbc hl,de
	sbc hl,bc
	call nz,System_ThrowException
	pop de
	pop bc
	ld ix,HeapTest_heap
	call Heap_Free
	ld ix,HeapTest_heap
	call Heap_GetFreeSpace
	and a
	ld hl,(HeapTest_heap + Heap.capacity)
	sbc hl,bc
	call nz,System_ThrowException
	ret

HeapTest_TestAllocationFragmented:
	; allocate two objects and then free the first
	ld bc,8
	ld ix,HeapTest_heap
	call Heap_Allocate
	exx
	ld bc,8
	ld ix,HeapTest_heap
	call Heap_Allocate
	push bc
	push de
	exx
	ld ix,HeapTest_heap
	call Heap_Free
	ld ix,HeapTest_heap
	call Heap_GetFreeSpace
	and a
	ld hl,(HeapTest_heap + Heap.capacity)
	ld de,8
	sbc hl,de
	sbc hl,bc
	call nz,System_ThrowException

	; allocate and free remaining space
	ld hl,-8
	add hl,bc
	ld c,l
	ld b,h
	ld ix,HeapTest_heap
	call Heap_Allocate
	push bc
	push de
	ld ix,HeapTest_heap
	call Heap_GetFreeSpace
	and a
	ld hl,8
	sbc hl,bc
	call nz,System_ThrowException
	pop de
	pop bc
	ld ix,HeapTest_heap
	call Heap_Free

	; free the last object
	pop de
	pop bc
	ld ix,HeapTest_heap
	call Heap_Free
	ld bc,(HeapTest_heap + Heap.capacity)
	ld ix,HeapTest_heap
	call Heap_CanAllocate
	call nc,System_ThrowException
	ret

;
	SECTION RAM

HeapTest_heap:
	Heap HeapTest_heapSpace, 20H

	ALIGN 4
HeapTest_heapSpace:
	ds 20H

	ENDS
