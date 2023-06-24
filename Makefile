# Sources
SRCS         = $(wildcard *.s)
BASENAME     = bootloader
HEX_FILE     = $(BASENAME).ihx
BIN_FILE     = $(BASENAME).bin
MEM_FILE     = $(BASENAME).mem
MAP_FILE     = $(BASENAME).map

VERSION_FILE = git_version.inc

REL_FILES    = $(SRCS:%.s=%.rel)
SYM_FILES    = $(SRCS:%.s=%.sym)
RST_FILES    = $(SRCS:%.s=%.rst)
LST_FILES    = $(SRCS:%.s=%.lst)

GENERATED    =  $(HEX_FILE) $(BIN_FILE) $(MEM_FILE) $(REL_FILES) $(SYM_FILES) $(RST_FILES) $(LST_FILES) $(VERSION_FILE) $(MAP_FILE)

# Version tag
TAG_COMMIT   = $(shell git rev-list --abbrev-commit --tags --max-count=1)
TAG          = $(shell git describe --abbrev=0 --tags ${TAG_COMMIT} 2>/dev/null || true)
COMMIT       = $(shell git rev-parse --short HEAD)
DATE         = $(shell git log -1 --format=%cd --date=format:"%Y%m%d")
VERSION      = $(TAG:v%=%)
VERSION_PARTS := $(subst ., ,$(VERSION))
VERSION_MAJOR := $(word 1, $(VERSION_PARTS))
VERSION_MINOR := $(word 2, $(VERSION_PARTS))

ifneq ($(COMMIT),$(TAG_COMMIT))
	VERSION := $(VERSION)-next-$(COMMIT)-$(DATE)
endif
ifeq ($(VERSION),"")
	VERSION := $(COMMIT)-$(DATE)
endif
ifneq ($(shell git status --porcelain -uno),)
	VERSION := $(VERSION)-dirty
endif

DEFINES  += -DGIT_VERSION_STR="\"$(VERSION)\""
DEFINES  += -DGIT_VERSION_MAJOR=$(VERSION_MAJOR)
DEFINES  += -DGIT_VERSION_MINOR=$(VERSION_MINOR)
DEFINES  += -DUSB_PID=$(USB_PID)
DEFINES  += -DUSB_VID=$(USB_VID)
DEFINES  += -DAPPIMG_OFFSET=$(APPIMG_OFFSET)

AS       = sdas8051
AR       = sdar8051
LD       = sdld
CC       = sdcc
CPP      = sdcpp

ASFLAGS  = -gcpwb
LDFLAGS  = -nuMmw -C 0x800

CPPFLAGS += -P $(DEFINES)

.PHONY: all info reset flash clean

info: $(MEM_FILE)
	@cat $(MEM_FILE)

all: info $(BIN_FILE)

flash: $(BIN_FILE)
	# My own hacked-together ESP32 based flasher
	ccflash write --erase --reset --verify $(BIN_FILE)

%.bin: %.ihx
	objcopy --input-target=ihex --output-target=binary $< $@

$(HEX_FILE) $(RST_FILES) $(MEM_FILE): $(REL_FILES) $(LST_FILES)
	$(LD) $(LDFLAGS) -i $(HEX_FILE) $(REL_FILES)

%.rel: %.s %.lst Makefile
	$(AS) $(ASFLAGS) -o $@ $<

%.lst: %.s
	$(AS) $(ASFLAGS) -l $@ $<

%.sym: %.s
	$(AS) $(ASFLAGS) -s $@ $<

main.s: $(VERSION_FILE)
device_desc.s: $(VERSION_FILE)
usb_descriptors.s: $(VERSION_FILE)

$(VERSION_FILE):
	echo "; AUTO-GENERATED FILE - DO NOT EDIT" > $@
	echo ".macro .str_version" >> $@
	echo "	.str \"$(VERSION)\"" >> $@
	echo ".endm" >> $@
	echo "GIT_VERSION_MAJOR = $(VERSION_MAJOR)" >> $@
	echo "GIT_VERSION_MINOR = $(VERSION_MINOR)" >> $@

clean:
	rm -f $(GENERATED)
