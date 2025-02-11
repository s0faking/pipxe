FW_URL		:= https://github.com/raspberrypi/firmware.git/trunk/boot

EFI_BUILD	:= RELEASE
EFI_ARCH	:= AARCH64
EFI_TOOLCHAIN	:= GCC5
EFI_TIMEOUT	:= 3
EFI_FLAGS	:= --pcd=PcdPlatformBootTimeOut=$(EFI_TIMEOUT)
EFI_DSC		:= edk2-platforms/Platform/RaspberryPi/RPi4/RPi4.dsc
EFI_FD		:= Build/RPi4/$(EFI_BUILD)_$(EFI_TOOLCHAIN)/FV/RPI_EFI.fd

IPXE_CROSS	:= aarch64-linux-gnu-
IPXE_SRC	:= ipxe/src
IPXE_TGT	:= bin-arm64-efi/snp.efi
IPXE_EFI	:= $(IPXE_SRC)/$(IPXE_TGT)

SDCARD_MB	:= 32
export MTOOLSRC	:= mtoolsrc

SHELL		:= /bin/bash

all : sdcard sdcard.img sdcard.zip

efi : $(EFI_FD)

efi-basetools :
	$(MAKE) -C edk2/BaseTools

$(EFI_FD) : efi-basetools
	. ./edksetup.sh && \
	build -b $(EFI_BUILD) -a $(EFI_ARCH) -t $(EFI_TOOLCHAIN) \
		-p $(EFI_DSC) $(EFI_FLAGS)

ipxe : $(IPXE_EFI)

$(IPXE_EFI) :
	$(MAKE) -C $(IPXE_SRC) CROSS=$(IPXE_CROSS) CONFIG=rpi $(IPXE_TGT)

sdcard : efi ipxe
	$(RM) -rf sdcard
	mkdir -p sdcard
	cp -r $(sort $(filter-out firmware/kernel%,$(wildcard firmware/*))) \
		sdcard/
	cp config.txt $(EFI_FD) edk2/License.txt sdcard/
	mkdir -p sdcard/efi/boot
	cp $(IPXE_EFI) sdcard/efi/boot/bootaa64.efi
	cp ipxe/COPYING* sdcard/

sdcard.img : sdcard
	truncate -s $(SDCARD_MB)M $@
	mpartition -I -c -b 32 -s 32 -h 64 -t $(SDCARD_MB) -a "z:"
	mformat -v "piPXE" "z:"
	mcopy -s sdcard/* "z:"

sdcard.zip : sdcard
	$(RM) -f $@
	( pushd $< ; zip -q -r ../$@ * ; popd )

update:
	git submodule foreach git pull origin master

tag :
	git tag v`git show -s --format='%ad' --date=short | tr -d -`

.PHONY : efi efi-basetools $(EFI_FD) ipxe $(IPXE_EFI) \
	 sdcard

clean :
	$(RM) -rf Build sdcard sdcard.zip
	if [ -d $(IPXE_SRC) ] ; then $(MAKE) -C $(IPXE_SRC) clean ; fi
