#!/usr/bin/env bash
set -euo pipefail

# Libera hugepages atuais e reserva 8GB (4096 paginas de 2MB)
echo 4096 | sudo tee /proc/sys/vm/nr_hugepages

# Recarrega o XML com memoryBacking + 8GB
virsh define /home/alsoasnerd/.config/nixos/win11-lookingglass.xml

# Inicia a VM
virsh start win11
