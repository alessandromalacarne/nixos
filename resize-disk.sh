#!/usr/bin/env bash
set -euo pipefail

IMG="/var/lib/libvirt/images/win11.qcow2"
NBD="/dev/nbd0"

echo "[1] Conectando imagem..."
sudo modprobe nbd max_part=8 2>/dev/null || true
sudo qemu-nbd --disconnect "$NBD" 2>/dev/null || true
sudo qemu-nbd --connect="$NBD" "$IMG"

echo "[2] Corrigindo backup GPT..."
sudo sgdisk --move-second-header "$NBD"

echo "[3] Layout atual:"
sudo sgdisk -p "$NBD"

echo "[4] Movendo partição de recovery e diag pro final..."
# Move todas as partições depois da C: pro espaço final
# Primeiro descobre qual é a última partição C:
C_PART=$(sudo sgdisk -p "$NBD" | grep -E "Microsoft basic data|0700" | tail -1 | awk '{print $1}')

# Move partições que estão depois da C: (recovery, diag, etc)
for p in $(sudo sgdisk -p "$NBD" | grep -E "^  +[0-9]+" | awk '{print $1}' | sort -n); do
  if [ "$p" -gt "$C_PART" ] 2>/dev/null; then
    echo "   Movendo partição $p pro final..."
    sudo sgdisk -d "$p" -n "0:0:0" -t "0:2700" -c "0:$(sudo sgdisk -i "$p" "$NBD" | grep "Partition name" | cut -d"'" -f2)" "$NBD" || true
  fi
done

echo "[5] Expandindo partição C: ($C_PART) pro espaço livre..."
sudo sgdisk -d "$C_PART" -N "$C_PART" "$NBD"

echo "[6] Redimensionando NTFS..."
sudo partprobe "$NBD" 2>/dev/null || sudo blockdev --rereadpt "$NBD" 2>/dev/null || true
sudo ntfsresize "${NBD}p${C_PART:?}"

echo "[7] Desconectando..."
sudo qemu-nbd --disconnect "$NBD"

echo ""
echo "Pronto! VM pode iniciar, Windows já vê 100G."
