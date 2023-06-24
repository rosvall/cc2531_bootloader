; SPDX-FileCopyrightText: 2023 Andreas Sig Rosvall
;
; SPDX-License-Identifier: GPL-3.0-or-later

DFU_VERSION_BCD = 0x0100

; DFU States
DFU_STATE_APPIDLE                = 0 ; Device is running its normal application.
DFU_STATE_APPDETACH              = 1 ; Device is running its normal application, has received the DFU_DETACH request, and is waiting for a USB reset.
DFU_STATE_DFUIDLE                = 2 ; Device is operating in the DFU mode and is waiting for requests.
DFU_STATE_DFUDNLOAD_SYNC         = 3 ; Device has received a block and is waiting for the host to solicit the status via DFU_GETSTATUS.
DFU_STATE_DFUDNBUSY              = 4 ; Device is programming a control-write block into its nonvolatile memories.
DFU_STATE_DFUDNLOAD_IDLE         = 5 ; Device is processing a download operation. Expecting DFU_DNLOAD requests.
DFU_STATE_DFUMANIFEST_SYNC       = 6 ; Device has received the final block of firmware from the host and is w aiting for receipt of DFU_GETSTATUS to begin the Manifestation phase; or device has completed the Manifestation phase and is waiting for receipt of DFU_GETSTATUS. (Devices that can enter this state after the Manifestation phase set bmAttributes bit bitManifestationTolerant to 1.)
DFU_STATE_DFUMANIFEST            = 7 ; Device is in the Manifestation phase. (Not all devices will be able to respond to DFU_GETSTATUS when in this state.)
DFU_STATE_DFUMANIFEST_WAIT_RESET = 8 ; Device has programmed its memories and is waiting for a USB reset or a power on reset. (Devices that must enter this state clear bitManifestationTolerant to 0.)
DFU_STATE_DFUUPLOAD_IDLE         = 9 ; The device is processing an upload operation. Expecting DFU_UPLOAD requests.
DFU_STATE_DFUERROR               = 10 ; An error has occurred. Awaiting the DFU_CLRSTATUS request.

; DFU Status codes
DFU_OK              = 0x00 ; No error condition is present.
DFU_ERRTARGET       = 0x01 ; File is not targeted for use by this device.
DFU_ERRFILE         = 0x02 ; File is for this device but fails some vendor-specific verification test.
DFU_ERRWRITE        = 0x03 ; Device is unable to write memory.
DFU_ERRERASE        = 0x04 ; Memory erase function failed.
DFU_ERRCHECK_ERASED = 0x05 ; Memory erase check failed.
DFU_ERRPROG         = 0x06 ; Program memory function failed.
DFU_ERRVERIFY       = 0x07 ; Programmed memory failed verification.
DFU_ERRADDRESS      = 0x08 ; Cannot program memory due to received address that is out of range.
DFU_ERRNOTDONE      = 0x09 ; Received DFU_DNLOAD with wLength = 0, but device does not think it has all of the data yet.
DFU_ERRFIRMWARE     = 0x0A ; Device’s firmware is corrupt. It cannot return to run-time (non-DFU) operations.
DFU_ERRVENDOR       = 0x0B ; iString indicates a vendor-specific error.
DFU_ERRUSBR         = 0x0C ; Device detected unexpected USB reset signaling.
DFU_ERRPOR          = 0x0D ; Device detected unexpected power on reset.
DFU_ERRUNKNOWN      = 0x0E ; Something went wrong, but the device does not know what it was.
DFU_ERRSTALLEDPKT   = 0x0F ; Device stalled an unexpected request.



; USB bRequests
USB_REQ_DFU_DETACH        =  0
USB_REQ_DFU_DNLOAD        =  1
USB_REQ_DFU_UPLOAD        =  2
USB_REQ_DFU_GETSTATUS     =  3
USB_REQ_DFU_CLRSTATUS     =  4
USB_REQ_DFU_GETSTATE      =  5
USB_REQ_DFU_ABORT         =  6


USB_SUBCLASS_DFU = 0x01

USB_CLASS_APP_SPEC = 0xFE

USB_INTERFACE_PROTO_RUNTIME = 0x01
USB_INTERFACE_PROTO_DFU     = 0x02


bitWillDetach            = 1 << 0
bitManifestationTolerant = 1 << 1
bitCanUpload             = 1 << 2
bitCanDnload             = 1 << 3
