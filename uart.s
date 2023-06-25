; SPDX-FileCopyrightText: 2023 Andreas Sig Rosvall
;
; SPDX-License-Identifier: GPL-3.0-or-later

.module uart

.include "bsp/uart.inc"
.include "bsp/gpio.inc"
.include "pins.inc"


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.area CSEG (CODE)

uart_setup::
	; 2 Mbaud 1N8 uart log output on P1.6

	mov P1SEL, #(1 << UART_TX_PIN)     ; Enable peripheral function on P1.6
	mov PERCFG, #PERCFG_U1_ALT2        ; Use i/o location 2 for USART1
	setb U1CSR_UART_MODE               ; Set mode to UART (not SPI)
	mov U1BAUD, #U1BAUD_BAUD_M_2000000 ; Baud mantissa
	mov U1GCR, #U1GCR_BAUD_E_2000000   ; Baud exponent
	ret


print_str_inline::
	; Print the null-terminated string following the call site,
	; and return to instruction following the null byte.

	; Pop "return" address = address of first char of null-terminated string
	pop dph
	pop dpl
	; We'll assume the first character is not null
	clr a
	movc a, @a+dptr
	print_loop:
		acall output_char
		inc dptr
		clr a
		movc a, @a+dptr
	jnz print_loop
	; dptr now points one past the null byte
	jmp @a+dptr


print_hex::
	; R0 = n = number of bytes + 1
	; Rn..R1 = bytes to print, MSB in Rn

	print_hex_loop:
		; most significant nybble
		mov a, @r0
		swap a
		acall print_hex_nybble

		; least significant nybble
		mov a, @r0
		acall print_hex_nybble
	djnz r0, print_hex_loop

	mov a, #'\n
	ajmp output_char


print_hex_nybble:
	acall hex_to_ascii
output_char:
	mov U1DBUF, a
	jb U1CSR_ACTIVE, .
	ret
