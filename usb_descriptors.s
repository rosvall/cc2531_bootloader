; SPDX-FileCopyrightText: 2023 Andreas Sig Rosvall
;
; SPDX-License-Identifier: GPL-3.0-or-later

.module usb_descriptors

.include "bsp/usb.inc"
.include "bsp/flash.inc"
.include "usb.inc"
.include "dfu.inc"
.include "config.inc"
.include "macros.inc"
.include "git_version.inc"
.include "bsp/mem.inc"
.include "bsp/infopage.inc"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.area CONST (CODE)


; Hack together a BCD version (git tag `v12.34` -> 0x1234)
BCD0 = GIT_VERSION_MINOR % 10
BCD1 = GIT_VERSION_MINOR / 10
BCD2 = GIT_VERSION_MAJOR % 10
BCD3 = GIT_VERSION_MAJOR / 10
BCD_VERSION = (BCD3 << 12) + (BCD2 << 8) + (BCD1 << 4) + (BCD0 << 0)

device_descriptor::
	d_bLength:            .db _end_device_descriptor - device_descriptor
	d_bDescriptorType:    .db USB_DT_DEVICE
	d_bcdUSB:             .lw USB_VERSION
	d_bDeviceClass:       .db USB_DEVICE_CLASS_DEVICE
	d_bDeviceSubClass:    .db USB_DEVICE_SUBCLASS_NONE
	d_bDeviceProtocol:    .db USB_DEVICE_PROTOCOL_PER_INTF
	d_bMaxPacketSize0:    .db USB_EP0_SIZE
	d_idVendor:           .lw USB_VID
	d_idProduct:          .lw USB_PID
	d_bcdDevice:          .lw BCD_VERSION
	d_iManufacturer:      .db USB_STRING_DESC_MANUFACTURER
	d_iProduct:           .db USB_STRING_DESC_PRODUCT
	d_iSerialNumber:      .db USB_STRING_DESC_SERIAL_NUM
	d_bNumConfigurations: .db 1
_end_device_descriptor:


TOTAL_CONF_LEN = _end_total_configuration - configuration_descriptor

configuration_descriptor::
	c_bLength:             .db _end_configuration_descriptor - configuration_descriptor
	c_bDescriptorType:     .db USB_DT_CONFIGURATION
	c_wTotalLength:        .lw TOTAL_CONF_LEN
	c_bNumInterfaces:      .db 1
	c_bConfigurationValue: .db 1
	c_iConfiguration:      .db 0
	c_bmAttributes:        .db bitBusPowered
	c_MaxPower:            .db VBUS_MAX_CURRENT_MA/2
_end_configuration_descriptor:
interface_descriptor:
	i_bLength:             .db _end_interface_descriptor - interface_descriptor
	i_bDescriptorType:     .db USB_DT_INTERFACE
	i_bInterfaceNumber:    .db 0
	i_bAlternateSetting:   .db 0
	i_bNumEndpoints:       .db 0
	i_bInterfaceClass:     .db USB_CLASS_APP_SPEC
	i_bInterfaceSubClass:  .db USB_SUBCLASS_DFU
	i_bInterfaceProtocol:  .db USB_INTERFACE_PROTO_DFU
	i_iInterface:          .db USB_STRING_DESC_DFU_IF
_end_interface_descriptor:
dfu_functional_descriptor:
	f_bLength:             .db _end_dfu_functional_descriptor - dfu_functional_descriptor
	f_bDescriptorType:     .db USB_DT_DFU_FUNCTIONAL
	f_bmAttributes:        .db bitCanDnload | bitCanUpload | bitManifestationTolerant | bitWillDetach
	f_wDetachTimeout:      .lw DETACH_TIMEOUT
	f_wTransferSize:       .lw FLASH_PAGE_SIZE
	f_bcdDFUVersion:       .lw DFU_VERSION_BCD
_end_dfu_functional_descriptor:
_end_total_configuration:


string_descriptor_langid::
	s_bLength:             .db _end_string_descriptor_langid - string_descriptor_langid
	s_bDescriptorType:     .db USB_DT_STRING
	s_wstr:                .lw LANGID_ENGLISH_US
_end_string_descriptor_langid:


; ASCII strings to be rendered as UTF-16LE

str_manufacturer::             .strz "Andreas Rosvall"

str_product::                  .strz "CC2531 USB (DFU MODE)"

str_dfu_block::                .strz "Firmware at 0x800"


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.area XSEG (XDATA,ABS)
.org 0x0100

; Dynamically generated ASCII hex string
str_serialnum:: .ds 16 + 1



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.area CSEG (CODE)

; Use the 64 bit permanent ieee 802.15.4 extended address as usb serial number string
render_str_serialnum::
	mov dptr, #str_serialnum
	mov MPAGE, #(INFOPAGE_PERM_ADDR >> 8)
	; stored as little endian, read MSB first
	mov r0, #(INFOPAGE_PERM_ADDR + 7)

	; 16 ascii characters
	mov b, #16
	1$:
		movx a, @r0
		jnb b.0, 2$
			swap a
			dec r0
		2$:
		swap a
		acall hex_to_ascii

		movx @dptr, a
		inc dptr
	djnz b, 1$
	; terminate with null char
	clr a
	movx @dptr, a
	ret
