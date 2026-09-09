#!/bin/bash
set -e

DISK="/data/windows11.qcow2"

if [ ! -f "$DISK" ]; then
    qemu-img create -f qcow2 "$DISK" 256G
fi

if [ ! -f /tpm/swtpm.sock ]; then
    rm -f /tpm/swtpm.sock

    swtpm socket \
        --tpm2 \
        --tpmstate dir=/tpm \
        --ctrl type=unixio,path=/tpm/swtpm.sock \
        --daemon
fi

qemu-system-x86_64 \
    -enable-kvm \
    -machine q35 \
    -cpu host \
    -m 32768 \
    -smp 8 \
    -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE_4M.fd \
    -drive if=pflash,format=raw,file=/data/OVMF_VARS.fd \
    -chardev socket,id=chrtpm,path=/tpm/swtpm.sock \
    -tpmdev emulator,id=tpm0,chardev=chrtpm \
    -device tpm-tis,tpmdev=tpm0 \
    -drive file="$DISK",format=qcow2 \
    -cdrom /iso/Win11.iso \
    -netdev user,id=net0,hostfwd=tcp::3389-:3389 \
    -device virtio-net-pci,netdev=net0 \
    -vnc :0
