; SPDX-FileCopyrightText: 2023 Andreas Sig Rosvall
;
; SPDX-License-Identifier: GPL-3.0-or-later

; little endian 16 bit word
.macro .lw val
	.db val
	.db (val)>>8
.endm

.macro .print str
	acall print
	.strz "'str"
.endm

.macro string_descriptor str
	.nchr	len,"'str"
	.db	len * 2 + 2
	.db	3
	.irpc	c,^"'str"
		.strz	"'c"
	.endm
.endm
