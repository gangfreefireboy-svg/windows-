#!/bin/bash
set -e

DATA_DIR="/data"
ISO_DIR="/iso"
TPM_DIR="/data/tpm"
TPM_SOCKET="/data/tpm/swtpm.sock"
DISK="/data/windows11.qcow2"
ISO="/iso/Win11.iso"

mkdir -p "$DATA_DIR" "$ISO_DIR" "$TPM_DIR"

echo "=== Windows 11 VM Starting ==="

# Check Windows ISO
if [ ! -f "$ISO" ]; then
    echo "ERROR: Windows ISO not found!"
    echo "Expected file: $ISO"
    echo "Put Win11.iso inside the /iso volume."
    exit 1
fi

echo "Windows ISO found."

# Create UEFI variables
if [ ! -f "/data/OVMF_VARS.fd" ]; then
    echo "Creating OVMF_VARS.fd..."
    cp /usr/share/OVMF/OVMF_VARS_4M.fd /data/OVMF_VARS.fd
fi

# Create Windows disk
if [ ! -f "$DISK" ]; then
    echo "Creating Windows disk..."
    qemu-img create -f qcow2 "$DISK" 256G
fi

# Remove old TPM socket
rm -f "$TPM_SOCKET"

# Start TPM 2.0
echo "Starting TPM..."

swtpm socket \
    --tpm2 \
    --tpmstate dir="$TPM_DIR" \
    --ctrl type=unixio,path="$TPM_SOCKET" \
    --daemon \
    --log file=/data/tpm/swtpm.log

# Wait for TPM socket
echo "Waiting for TPM socket..."

for i in $(seq 1 30); do
    if [ -S "$TPM_SOCKET" ]; then
        echo "TPM socket ready!"
        break
    fi

    sleep 1
done

# Verify TPM actually exists
if [ ! -S "$TPM_SOCKET" ]; then
    echo "ERROR: TPM failed to start."
    echo "TPM log:"
    cat /data/tpm/swtpm.log 2>/dev/null || true
    exit 1
fi

echo "Starting Windows 11..."

# Start noVNC
websockify \
    --web=/usr/share/novnc \
    6080 \
    127.0.0.1:5900 &

# Start QEMU
exec qemu-system-x86_64 \
    -enable-kvm \
    -machine q35 \
    -cpu host \
    -m 32768 \
    -smp 8 \
    -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE_4M.fd \
    -drive if=pflash,format=raw,file=/data/OVMF_VARS.fd \
    -chardev socket,id=chrtpm,path="$TPM_SOCKET" \
    -tpmdev emulator,id=tpm0,chardev=chrtpm \
    -device tpm-tis,tpmdev=tpm0 \
    -drive file="$DISK",format=qcow2 \
    -cdrom "$ISO" \
    -netdev user,id=net0,hostfwd=tcp::3389-:3389 \
    -device virtio-net-pci,netdev=net0 \
    -vnc :0
