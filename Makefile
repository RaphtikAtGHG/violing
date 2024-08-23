MAKEFLAGS += --no-print-directory

CXX := clang
LD := ld.lld
CXXFLAGS := -target x86_64-windows-unknown -ffreestanding -fshort-wchar \
           -Wno-unused-command-line-argument -Wno-void-pointer-to-int-cast \
           -Wno-int-to-void-pointer-cast -Wno-int-to-pointer-cast -g -Ilib 

LDFLAGS := -target x86_64-windows-unknown -nostdlib \
          -Wl,-entry:boot_main -Wl,-subsystem:efi_application -fuse-ld=lld-link -g

OBJ_DIR := build
BIN_DIR := bin
TARGET := $(BIN_DIR)/violin.efi
IMAGE_NAME := boot.img
UEFI_FIRMWARE := /usr/share/OVMF/x64/OVMF.fd

.PHONY: all build $(BIN_DIR)/$(IMAGE_NAME) run clean

SRC_FILES := $(shell find src -name '*.c')
OBJ_FILES := $(SRC_FILES:src/%.c=$(OBJ_DIR)/%.o)

all: build $(BIN_DIR)/$(IMAGE_NAME)

build: $(TARGET)

$(TARGET): $(OBJ_FILES)
	@$(CXX) $(LDFLAGS) -o $@ $(OBJ_FILES)

$(OBJ_DIR)/%.o: src/%.c
	@mkdir -p $(dir $@)
	@$(CXX) $(CXXFLAGS) -c $< -o $@

$(BIN_DIR)/$(IMAGE_NAME): $(TARGET)
	@dd if=/dev/zero of=$(BIN_DIR)/$(IMAGE_NAME) bs=1M count=64 status=progress
	@mkfs.fat -F32 -n EFI_SYSTEM $(BIN_DIR)/$(IMAGE_NAME)
	@mmd -i $(BIN_DIR)/$(IMAGE_NAME) ::/EFI
	@mmd -i $(BIN_DIR)/$(IMAGE_NAME) ::/EFI/BOOT
	@mcopy -i $(BIN_DIR)/$(IMAGE_NAME) $(TARGET) ::/EFI/BOOT/BOOTX64.EFI
	@mdir -i $(BIN_DIR)/$(IMAGE_NAME)  ::/EFI/BOOT/
	@echo "Image created: $(BIN_DIR)/$(IMAGE_NAME)"

run: $(BIN_DIR)/$(IMAGE_NAME)
	@qemu-system-x86_64 -drive file=$(BIN_DIR)/$(IMAGE_NAME),format=raw -m 2G \
		-drive if=pflash,unit=0,format=raw,file=/usr/share/OVMF/x64/OVMF_CODE.fd,readonly=on \
		-drive if=pflash,unit=1,format=raw,file=/usr/share/OVMF/x64/OVMF_VARS.fd -boot order=c

clean:
	@rm -rf $(OBJ_DIR) $(BIN_DIR) $(TARGET) $(IMAGE_NAME)
