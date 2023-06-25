; SPDX-FileCopyrightText: 2023 Andreas Sig Rosvall
;
; SPDX-License-Identifier: GPL-3.0-or-later

.module dfu_mode

.include "bsp/dma.inc"
.include "bsp/mem.inc"
.include "bsp/flash.inc"
.include "bsp/usb.inc"
.include "bsp/chipinfo.inc"
.include "bsp/gpio.inc"
.include "bsp/watchdog.inc"

.include "macros.inc"
.include "usb.inc"
.include "dfu.inc"

.include "config.inc"
.include "pins.inc"

; Bootloader uses flash page 0 = first 2kB
; App starts at flash page 1

; NOTE: Using r7 for USB control endpoint state
STATE_IDLE   = 0
STATE_RX     = 1
STATE_TX     = 2
STATE_STALL  = 3

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.area DSEG (DATA)

; DFU status payload
dfu_status: .ds 1
dfu_poll_timeout_0: .ds 1
dfu_poll_timeout_1: .ds 1
dfu_poll_timeout_2: .ds 1
dfu_state: .ds 1
dfu_istring: .ds 1
dfu_status_end:

; USB state
current_configuration: .ds 1
alternate_setting: .ds 1

; DMA CH  0
dma_desc_tx:
	dma_tx_src_h: .ds 1
	dma_tx_src_l: .ds 1

	dma_tx_dst_h: .ds 1
	dma_tx_dst_l: .ds 1

	wLengthH:
	dma_tx_len_h: .ds 1
	wLengthL:
	dma_tx_len_l: .ds 1

	dma_tx_cfg_h: .ds 1
	dma_tx_cfg_l: .ds 1


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.area XSEG (XDATA,ABS)
.org 0x0000

string_descriptor:
	string_desc_bLen:  .ds 1
	string_desc_bType: .ds 1
	string_desc_wstr:  .ds 0x100 - 2

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.area CSEG (CODE)

; DMA CH 1 config (constant)
dma_desc_rx:
	; src
	.dw USBF0
	; dest
	.dw FWDATA
	; length
	.dw USB_EP0_SIZE
	; settings
	.db DMA_TRIG_FLASH
	.db DMA_SRC_CONST | DMA_DST_CONST | DMA_PRIO_HIGH


dfu_mode::
	.print ^"DFU MODE\n"

	; Enable output pins
	orl P1DIR, #( (1 << USB_DPLUS_PIN) | (1 << LED_RED_PIN) )

	; Enable USB and USB PLL
	mov dptr, #USBCTRL
	mov a, #(USBCTRL_USB_EN | USBCTRL_PLL_EN)
	movx @dptr, a
	wait_for_usb_pll_to_settle:
		movx a, @dptr
	jnb a.7, wait_for_usb_pll_to_settle

	acall get_firmware_size

	acall render_str_serialnum

	; DMA ch 0 = TX
	mov DMA0CFGH, #(DATA_IN_XDATA >> 8)
	mov DMA0CFGL, #dma_desc_tx

	; Fill out the constant parts of the TX DMA config
	mov dma_tx_dst_h, #(USBF0 >> 8)
	mov dma_tx_dst_l, #USBF0
	mov dma_tx_cfg_h, #DMA_TRIG_NONE
	mov dma_tx_cfg_l, #(DMA_SRC_INC_1 | DMA_DST_CONST | DMA_PRIO_HIGH)

	; DMA ch 1 = RX
	dma_desc_rx_xmap = XMAP + dma_desc_rx
	mov DMA1CFGH, #(dma_desc_rx_xmap >> 8)
	mov DMA1CFGL, #dma_desc_rx_xmap

	; Since we're in DFU mode, there's probably something wrong...
	mov dfu_state, #DFU_STATE_DFUIDLE
	mov dfu_status, #DFU_ERRUNKNOWN
	mov dfu_poll_timeout_0, #0
	mov dfu_poll_timeout_1, #0
	mov dfu_poll_timeout_2, #0

	; Let the USB host know that we're online and ready
	setb USB_DPLUS

	; Loop forever
	dfu_main_loop:
		; Feed watchdog
		mov WDCTL, #WDCTL_FEED1
		mov WDCTL, #WDCTL_FEED2

		; Blink red led using usb frame number/1024 as clock
		mov dptr, #USBFRMH
		movx a, @dptr
		rrc a
		rrc a
		mov LED_RED, c

		; Check usb interrupt flags
		acall check_intr_flags
	sjmp dfu_main_loop


check_intr_flags:
	; Check common usb intr flags
	mov dptr, #USBCIF
	movx a, @dptr
	jnz  usb_reset

	; Check IN ep usb intr flags
	mov dptr, #USBIIF
	movx a, @dptr
	jnz check_usbcs0_flags

	ret


usb_reset:
	.print ^"usb reset\n"

	; if fw_last_page == 0
	mov a, fw_last_page
	jnz 1$
		; no firmware, only bootloader
		mov dfu_state, #DFU_STATE_DFUERROR
		mov dfu_status, #DFU_ERRFIRMWARE
	1$:

	; boot app if dfu_status == DFU_OK (= 0)
	mov a, dfu_status
	jnz 2$
		ajmp boot_app
	2$:

	; Reset usb state
	mov r7, #STATE_IDLE
	mov current_configuration, #0
	mov alternate_setting, #0

	ret


check_usbcs0_flags:
	OUTPKT_RDY     = 0
	INPKT_RDY      = 1
	SENT_STALL     = 2
	DATA_END       = 3
	SETUP_END      = 4
	SEND_STALL     = 5
	CLR_OUTPKT_RDY = 6
	CLR_SETUP_END  = 7

	mov dptr, #USBCS0
	movx a, @dptr
	mov b, a

	jnb b + SETUP_END, 1$
		mov a, #(1 << CLR_SETUP_END)
		movx @dptr, a
		mov r7, #STATE_IDLE
	1$:

	jnb b + SENT_STALL, 2$
		clr a
		movx @dptr, a
		mov r7, #STATE_IDLE

		.print ^"sent stall\n"
	2$:

	jnb b + OUTPKT_RDY, 3$
		cjne r7, #STATE_IDLE, 31$
			acall handle_request
			sjmp 32$
		31$:
		cjne r7, #STATE_RX, 32$
			acall recv_chunk
		32$:

		mov a, #(1 << CLR_OUTPKT_RDY)
		cjne r7, #STATE_STALL, 33$
			setb acc + SEND_STALL
		33$:

		cjne r7, #STATE_IDLE, 34$
			setb acc + DATA_END
		34$:

		mov dptr, #USBCS0
		movx @dptr, a
	3$:

	cjne r7, #STATE_TX, 4$
		acall send_chunk

		mov a, #(1 << INPKT_RDY)

		cjne r7, #STATE_IDLE, 41$
			setb acc + DATA_END
		41$:

		mov dptr, #USBCS0
		movx @dptr, a
	4$:

	ret


send_chunk:
	; trig dma ch0 USB_EP0_SIZE (= 32) times
	mov r0, #USB_EP0_SIZE
	1$:
		; stop if dma is out of data
		mov a, DMAARM
		jz no_more_data_to_send

		; else trig dma
		mov DMAREQ, #DMA_CH0
	djnz r0, 1$
	ret

	no_more_data_to_send:
	mov r7, #STATE_IDLE
	ret


recv_chunk:
	; Use dma to receive a 32 byte chunk and flash it
	mov DMAARM, #DMA_CH1
	mov dptr, #FCTL
	mov a, #FCTL_WRITE
	movx @dptr, a
	ret


handle_request:
	.print ^"req: "

	; Receive the 8 byte usb setup header 
	mov dptr, #USBF0

	; r4 = bmRequestType
	movx a, @dptr
	mov r4, a

	; Get the 'class' bit
	; We'll use it to differentiate between standard requests and DFU requests
	mov c, a.5

	; r3 = bRequest
	movx a, @dptr
	mov r3, a

	; r6 = (bRequest & 0b111) | (class_bit << 3)
	anl a, #0b111
	mov a.3, c
	mov r6, a

	; r1 = wValueL
	movx a, @dptr
	mov r1, a
	; r2 = wValueH
	movx a, @dptr
	mov r2, a

	; discard wIndex - we're not using it for anything
	movx a, @dptr
	movx a, @dptr

	; receive wLength into dma tx descriptor
	movx a, @dptr
	mov wLengthL, a
	movx a, @dptr
	mov wLengthH, a

	; print bmRequestType, bRequest, and wValue as hex
	mov r0, #4
	acall print_hex

	; use r6 as index to jumptable
	mov a, r6
	; ajmp's are 2 bytes each
	rl a
	mov dptr, #jumptable
	jmp @a+dptr
	jumptable:
		; std
		ajmp get_configuration    ; std  8 get configuration
		ajmp set_configuration    ; std  9 set configuration
		ajmp get_intf_altsetting  ; std 10 get intf
		ajmp set_intf_altsetting  ; std 11 set intf
		ajmp stall                ; std  4 reserved
		ajmp set_address          ; std  5 set address
		ajmp get_descriptor       ; std  6 get descriptor
		ajmp stall                ; std  7 set descriptor
		; dfu
		ajmp dfu_detach           ; cls  0 dfu detach
		ajmp dfu_dnload           ; cls  1 dfu dnload
		ajmp dfu_upload           ; cls  2 dfu upload
		ajmp dfu_getstatus        ; cls  3 dfu getstatus
		ajmp dfu_clrstatus        ; cls  4 dfu clrstatus
		ajmp dfu_getstate         ; cls  5 dfu getstate
		ajmp dfu_abort            ; cls  6 dfu abort
		ajmp stall                ; cls  7 ?


stall:
	mov r7, #STATE_STALL
	ret


get_descriptor:
	; r1 = wValueL = desc_index
	; r2 = wValueH = desc_type

	.print ^"get descriptor\n"

	; We'll need to have flash bank 0 mapped into xdata
	mov MEMCTR, #0

	; Select descriptor by type
	mov a, r2

	dec a
	; 1 USB_DT_DEVICE
	mov dptr, #(XMAP + device_descriptor)
	jz send_descriptor

	dec a
	; 2 USB_DT_CONFIGURATION
	mov dptr, #(XMAP + configuration_descriptor)
	jz send_descriptor

	dec a
	; 3 USB_DT_STRING
	jnz stall

	; Select string descriptor by index
	mov a, r1

	; 0 USB_STRING_DESC_LANGID
	mov dptr, #(XMAP + string_descriptor_langid)
	jz send_descriptor

	dec a
	; 1 USB_STRING_DESC_MANUFACTURER
	mov dptr, #(XMAP + str_manufacturer)
	jz render_string_descriptor

	dec a
	; 2 USB_STRING_DESC_PRODUCT
	mov dptr, #(XMAP + str_product)
	jz render_string_descriptor

	dec a
	; 3 USB_STRING_DESC_SERIAL_NUM
	mov dptr, #str_serialnum
	jz render_string_descriptor

	dec a
	; 4 USB_STRING_DESC_DFU_IF
	mov dptr, #(XMAP + str_dfu_block)
	jnz stall


	render_string_descriptor:
		; We have a null-terminated ascii string at dptr
		; now we render a usb string descriptor into the buffer at `string_descriptor`

		mov MPAGE, #(string_descriptor >> 8)
		mov r0, #string_desc_wstr

		movx a, @dptr
		1$:
			; copy char
			movx @r0, a
			inc r0

			; add null (to expand to UTF16-LE encoding)
			clr a
			movx @r0, a
			inc r0

			inc dptr
			movx a, @dptr
		jnz 1$

		; r0 points to end of descriptor + 1
		; descriptor starts at 0x0100, so r0 = length
		mov a, r0
		mov r1, #string_desc_bLen
		movx @r1, a

		mov a, #USB_DT_STRING
		inc r1
		movx @r1, a

		mov dptr, #string_descriptor

	send_descriptor:

	mov dma_tx_src_h, dph
	mov dma_tx_src_l, dpl

	; set wLength = min(wLength, descriptor_size)
	mov a, wLengthH
	jnz wlength_is_bigger
		; read descriptor length
		movx a, @dptr
		mov r0, a
		; r0 = descriptor bLength field

		; special case for configuration descriptor. ugh.
		inc dptr
		movx a, @dptr
		cjne a, #USB_DT_CONFIGURATION, 1$
			inc dptr
			movx a, @dptr
			mov r0, a
			; r0 = wTotalLength low byte
		1$:

		; r0 = length
		clr c
		mov a, r0
		subb a, wLengthL
		jnc wlength_is_smaller
	wlength_is_bigger:
		mov wLengthL, r0
		mov wLengthH, #0
	wlength_is_smaller:
	; it's all good

	ajmp setup_dma_tx


set_address:
	; r1 = wValueL = address
	; r2 = wValueH

	.print ^"set address\n"
	
	mov dptr, #USBADDR
	mov a, r1
	movx @dptr, a

	mov current_configuration, #0
	ret


set_configuration:
	; r1 = wValueL = configuration
	; r2 = wValueH
	.print ^"set conf\n"
	mov current_configuration, r1
	ret


get_configuration:
	.print ^"get conf\n"
	mov dma_tx_src_l, #current_configuration
	ajmp setup_dma_tx_from_iram


get_intf_altsetting:
	.print ^"get intf\n"
	mov dma_tx_src_l, #alternate_setting
	ajmp setup_dma_tx_from_iram


dfu_getstate:
	.print ^"get state\n"
	mov dma_tx_src_l, #dfu_state
	ajmp setup_dma_tx_from_iram


dfu_getstatus:
	.print ^"get status: "
	mov r1, dfu_status
	mov r2, dfu_state
	mov r0, #2
	acall print_hex

	mov dma_tx_src_l, #dfu_status
setup_dma_tx_from_iram:
	mov dma_tx_src_h, #(DATA_IN_XDATA >> 8)
setup_dma_tx:
	mov DMAARM, #DMA_CH0
	mov r7, #STATE_TX
	ret


set_intf_altsetting:
	; r1 = wValueL = alt_setting
	; r2 = wValueH
	.print ^"set intf\n"
	mov alternate_setting, r1
	ret


dfu_dnload:
	; r1 = wValueL = page - 1
	; r2 = wValueH
	mov a, r1

	; erase old fw before writing chunk 0 = page 1
	jnz 1$
		acall erase_old_fw
	1$:

	inc r1
	; r1 = page

	.print ^"dnload "
	mov r0, #1
	acall print_hex

	; if request.wLength == 0
	mov a, wLengthL
	orl a, wLengthH
	jz dnload_done

	mov a, r1
	jz invalid_page

	clr c
	subb a, flash_page_count
	jnc invalid_page

	; r1                 0PPPpppp         
	; FADDRL                      00000000
	; FADDRH              PPPpppp0        

	mov dptr, #FADDRL
	clr a
	movx @dptr, a

	inc dptr
	
	mov a, r1
	rl a
	movx @dptr, a

	mov r7, #STATE_RX
	mov dfu_state, #DFU_STATE_DFUDNLOAD_IDLE
	ret

invalid_page:
	.print ^"invalid page\n"
	mov dfu_state, #DFU_STATE_DFUERROR
	mov dfu_status, #DFU_ERRADDRESS
	ajmp stall

dnload_done:
	.print ^"dnload done\n"
	acall get_firmware_size
	mov dfu_state, #DFU_STATE_DFUIDLE
	ret


erase_old_fw:
	; erase flash pages from fw_last_page down to 1 (both included)
	.print ^"erase old fw\n"
	mov a, fw_last_page
	jz 1$
		mov r1, a
		2$:
			.print ^"erase "
			mov r0, #1
			acall print_hex

			mov dptr, #FADDRH
			mov a, r1
			rl a
			movx @dptr, a

			mov dptr, #FCTL
			mov a, #FCTL_ERASE
			movx @dptr, a

			mov WDCTL, #WDCTL_FEED1
			mov WDCTL, #WDCTL_FEED2
		djnz r1, 2$
	1$:
	ret


dfu_upload:
	; r1 = wValueL = page - 1
	; r2 = wValueH
	inc r1

	; r1 = page

	.print ^"upload "
	mov r0, #1
	acall print_hex

	; we're done if page > fw_last_page
	mov a, fw_last_page
	clr c
	subb a, r1
	jc upload_done
		; r1                 0PPPpppp           
		; MEMCTR         00000PPP               
		; dma_tx_src_h          1pppp000        
		; dma_tx_src_l                  00000000

		mov a, r1
		swap a
		mov r6, a
		anl a, #0b00000111
		mov MEMCTR, a

		mov a, r6
		anl a, #0b11110000
		setb c
		rrc a
		mov dma_tx_src_h, a
		mov dma_tx_src_l, #0

		mov dfu_state, #DFU_STATE_DFUUPLOAD_IDLE
		ajmp setup_dma_tx
	upload_done:
	mov dfu_state, #DFU_STATE_DFUIDLE
	; send 0 bytes to indicate end of fw image
	mov r7, #STATE_TX
	ret


dfu_detach:
dfu_abort:
dfu_clrstatus:
	.print ^"clrstatus\n"
	mov dfu_state, #DFU_STATE_DFUIDLE
	mov dfu_status, #DFU_OK
	ret

