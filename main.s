; SPDX-FileCopyrightText: 2023 Andreas Sig Rosvall
;
; SPDX-License-Identifier: GPL-3.0-or-later

.module main

.include "bsp/clock.inc"
.include "bsp/watchdog.inc"
.include "bsp/gpio.inc"
.include "bsp/uart.inc"
.include "bsp/sleep.inc"
.include "bsp/usb.inc"
.include "bsp/mem.inc"
.include "pins.inc"
.include "macros.inc"
.include "config.inc"
.include "git_version.inc"


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.area REG_BANK_0 (DATA)
	.ds 8


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.area SSEG
stack:	.ds 1


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.area HOME (CODE,ABS)
	.org 0x0

reset:
	ajmp	bootloader
interrupt_table:
fwimg = 0x800 ; Start of application firmware
n = 0
.rept 18
	.org 3 + 8*n
	; Jump to app image interrupt table
	ljmp . + fwimg
	n = n + 1
.endm


bootloader::
        mov sp, #stack - 1

	; Set up clock
	mov a, #CLKSPD_32M
	mov CLKCONCMD, a
	; Wait for clock to settle
	cjne a, CLKCONSTA, .

	; Enable watchdog
	mov WDCTL, #(WDCTL_WATCHDOG_MODE | WDCTL_250MS)

	; Set up uart for logging output
	acall uart_setup

	; Show banner with version
	acall print
	.str "Bootloader "
	.str_version
	.strz "\n"

	; Figure out what happened
	mov a, SLEEPSTA
	anl a, #(0b11 << 3)

	cjne a, #SLEEPSTA_WATCHDOG, 1$
		.print ^"Watchdog triggered\n"
		ajmp dfu_mode
	1$:

	cjne a, #SLEEPSTA_CLOCKLOSS, 2$
		.print ^"Clockloss detected\n"
		ajmp dfu_mode
	2$:

	; Button (active low) held during boot: DFU mode
	jnb BTN0, button_pressed
	jnb BTN1, button_pressed

	; Everything looks OK, boot normal app image
boot_app::
	.print ^"Trying to boot app at 0x800...\n"

	; Reset everything back to defaults, except watchdog

	mov sp, #7

	clr a
	mov U1BAUD, a
	mov U1GCR, a
	mov U1CSR, a
	mov P0DIR, a
	mov P1DIR, a
	mov P1SEL, a
	mov PERCFG, a
	mov MPAGE, a
	mov MEMCTR, a

	mov dptr, #USBCTRL
	movx @dptr, a

	; reset to default clk settings
	mov CLKCONCMD, #CLKCONCMD_DEFAULTS

	ljmp fwimg


button_pressed:
	.print ^"Button pressed\n"
	ajmp dfu_mode
