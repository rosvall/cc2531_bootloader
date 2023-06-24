; SPDX-FileCopyrightText: 2023 Andreas Sig Rosvall
;
; SPDX-License-Identifier: GPL-3.0-or-later

.module firmware_size
.include "bsp/mem.inc"
.include "bsp/flash.inc"
.include "bsp/watchdog.inc"
.include "macros.inc"


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.area DSEG (DATA)

; number of available 2k pages installed in chip
flash_page_count:: .ds 1

; last written page
fw_last_page:: .ds 1

; last written byte in last written page
fw_last_byte_l:: .ds 1
fw_last_byte_h:: .ds 1


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.area CSEG (CODE)


; Figure out size of installed firmware by scanning through flash backwards to
; find the first byte that isn't 0xFF.
get_firmware_size::

	; First find size of flash by finding the number of 32k-sized flash banks
	; If we set MEMCTR to a non-existent bank, it won't stick

	mov a, #MAX_BANK_COUNT
	try_lower_bank:
		mov r2, a
		dec a
		mov MEMCTR, a
	cjne a, MEMCTR, try_lower_bank

	; r2 = number 32k flash banks available
	; Calculate and store number of pages = a * 16 = a << 4
	mov a, r2
	swap a
	mov flash_page_count, a

	mov r1, a
	.print ^"flash page count: "
	mov r0, #1
	acall print_hex
	
	; Now loop through flash backwards to find the first non-0xff byte
	; We're only looking in the high 32k, where we can map all flash in
	; MEMCTR is set to highest bank
	memctr_loop:
		mov r1, #0x80
		mov MPAGE, #0
		mpage_loop:
			dec MPAGE
			mov r0, #0
			inner_loop:
				dec r0
				movx a, @r0
				inc a
				jnz found_a_written_byte
			cjne r0, #0, inner_loop
		djnz r1, mpage_loop

		; Feed watchdog
		mov WDCTL, #WDCTL_FEED1
		mov WDCTL, #WDCTL_FEED2

		dec MEMCTR
	djnz r2, memctr_loop

	; Unreachable: We didn't find a single written byte in flash

found_a_written_byte:
	; MEMCTR      00000PPP               
	; MPAGE              1ppppHHH        
	; R0                         LLLLLLLL
	; last_page       0PPPpppp           
	; last_byte_h        00000HHH        
	; last_byte_l                LLLLLLLL

	.print ^"fw last byte: "

	mov fw_last_byte_l, r0
	mov a, MPAGE
	anl a, #0b111
	mov fw_last_byte_h, a

	mov r2, a
	mov r1, fw_last_byte_l
	mov r0, #2
	acall print_hex


	.print ^"fw last page: "

	mov a, MPAGE
	rl a
	anl a, #0xf0
	orl a, MEMCTR
	swap a
	mov fw_last_page, a

	mov r1, a
	mov r0, #1
	acall print_hex
	
	; reset MEMCTR and MPAGE
	mov MPAGE, #0
	mov MEMCTR, #0

	ret
