; SPDX-FileCopyrightText: 2023 Andreas Sig Rosvall
;
; SPDX-License-Identifier: GPL-3.0-or-later

; DFU Mode usb vid/pid
USB_VID       = 0x1608
USB_PID       = 0xffff

; Flash/code address space start of actual firmware
APPIMG_OFFSET = 0x800

; DFU detach timeout
DETACH_TIMEOUT = 100

; String descriptor indices
USB_STRING_DESC_MANUFACTURER = 1
USB_STRING_DESC_PRODUCT      = 2
USB_STRING_DESC_SERIAL_NUM   = 3
USB_STRING_DESC_DFU_IF       = 4
