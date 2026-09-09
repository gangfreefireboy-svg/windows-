#!/bin/bash
set -e

mkdir -p /data /iso /tpm

# Create UEFI variables file if it doesn't exist
if [ ! -f /data/OVMF_VARS.fd ]; then
    cp /usr/share/OVMF/OVMF_VARS_4M.fd /data/OVMF_VARS.fd
fi

# Create Windows virtual disk if it doesn't exist
DISK="/data/windows11.qcow2"

if [ ! -f "$DISK" ]; then
    qemu-img create -f qcow2 "$DISK" 256G
fi

# Create TPM state
if [ ! -d /data/tpm ]; then
    mkdir -p /data/tpm
fi

# Start software TPM 2.0
if [ ! -S /data/tpm/swtpm.sock ]; then
    swtpm socket \
        --tpm2 \
        --tpmstate dir=/data/tpm \
        --ctrl type=unixio,path=/data/tpm/swtpm.sock \
        --daemon
fi

# Start Windows 11 VM
qemu-system-x86_64 \
    -enable-kvm \
    -machine q35 \
    -cpu host \
    -m 32768 \
    -smp 8 \
    -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE_4M.fd \
    -drive if=pflash,format=raw,file=/data/OVMF_VARS.fd \
    -chardev socket,id=chrtpm,path=/data/tpm/swtpm.sock \
    -tpmdev emulator,id=tpm0,chardev=chrtpm \
    -device tpm-tis,tpmdev=tpm0 \
    -drive file="$DISK",format=qcow2 \
    -cdrom /iso/Win11.iso \
    -netdev user,id=net0,hostfwd=tcp::3389-:3389 \
    -device virtio-net-pci,netdev=net0 \
    -vnc :0
