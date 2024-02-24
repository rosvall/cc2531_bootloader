# Simple USB DFU bootloader for TI CC2531

*See [this hack](https://github.com/rosvall/cc2531_oem_flasher) for how to flash a stock CC2531USB-RD dongle*

Fits in the first flash page (2 kB).

If either

 - watchdog is triggered,
 - clockloss is detected,
 - or a button is held while booting

it enters DFU (USB device firmware upgrade) mode. Otherwise it jumps to code address 0x800 to boot your actual application firmware.

As the bootloader resides in the first 2 kB of the code address space, any firmware used with this bootloader must be compiled with code addresses offset by +0x800.

To compile firmware for use with this bootloader with SDCC, just add `--code-loc 0x800` to your CFLAGS.

The interrupt table in the bootloader is filled with jumps to the corresponding offset address, so apart from the extra delay of a `ljmp` instruction, interrupts will work normally for application firmware.

Note that the bootloader enables the watchdog with a timeout of 250 ms! This means your firmware must periodically feed the watchdog (it can't be disabled), or the device will reboot to DFU mode.

In DFU mode, it presents itself af a USB DFU 1.1 device to the USB host and allows both download (flashing) and upload (reading) for all flash from 0x800 and up. It will not overwrite itself though.

To read or write flash, use a program like [dfu-util](https://sourceforge.net/projects/dfu-util/).

## Requirements
- [SDCC](https://sourceforge.net/projects/sdcc/)
- [binutils](https://www.gnu.org/software/binutils/)
- [make](https://www.gnu.org/software/make/)

## How to build
Just run `make` to build the raw binary image bootloader.bin

## Known issues

 - It is not completely conformant to either USB 1.1 or DFU 1.1, and is only tested on Linux using dfu-utils.
 - It's currently using USB vendor id 0x1608 (Inside Out Networks), which is listed as "obsolete" by USB IF. This can be changed in `config.inc`. I'd like ideas for a better solution.
 - It's written in 8051 assembler. This is on purpose, though. It started out written in C (using SDCC), but i quickly grew tired of trying to get SDCC to generate sensible code.

*Feel free to submit a bug or pull request.*

## References
 - [CC253x/4x User's Guide (Rev. D)](https://www.ti.com/lit/pdf/swru191)
 - [8051 Instruction Set](https://www.win.tue.nl/~aeb/comp/8051/set8051.html)
 - [Universal Serial Bus Device Class Specification for Device Firmware Upgrade](https://www.usb.org/sites/default/files/DFU_1.1.pdf)
 - [USB 2.0 Specification](https://www.usb.org/sites/default/files/usb_20_20230224.zip)

## See also
 - [Flash a stock Texas Instruments CC2531USB-RD dongle, no tools required](https://github.com/rosvall/cc2531_oem_flasher)
 - [WPAN Adapter firmware for CC2531 USB Dongle](https://github.com/rosvall/cc2531_usb_wpan_adapter)
 - [Linux kernel driver for CC2531 WPAN Adapter firmware](https://github.com/rosvall/cc2531_linux)
