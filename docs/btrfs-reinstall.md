# Reinstall `nixos` on btrfs

Runbook for wiping `nvme0n1` and reinstalling from the flake with btrfs
subvolumes instead of the single ext4 root.

Layout after this runbook:

| Partition     | Size | FS    | Mount        |
| ------------- | ---- | ----- | ------------ |
| `nvme0n1p1`   | 1G   | vfat  | `/boot` ESP  |
| `nvme0n1p2`   | rest | btrfs | subvolumes   |

Subvolumes on `nvme0n1p2`: `@` → `/`, `@home` → `/home`, `@nix` → `/nix`,
`@log` → `/var/log`. All mounted with `compress=zstd:3,noatime,ssd,discard=async`.

No swap partition: `zramSwap` is enabled and hibernation is not configured.
No LUKS, no snapper.

## 0. Before wiping anything

Everything below is unrecoverable.

- Commit and push this branch, then merge it into the default branch. Flakes
  only see **git-tracked** files, and the live ISO clones from GitHub.
- Back up, outside `nvme0n1`:
  - `~/.config/sops/age/keys.txt` — decrypts `secrets/users.yaml.sops`; lose it
    and the `jiwolfsly`/`dummy` passwords are gone.
  - `~/.ssh/id_ed25519*` and `~/.ssh/allowed_signers` (referenced by `git.nix`).
  - `~/.secrets/agents`, `~/.local/share/ai-memory`.
  - `~/projects`, `~/Documents/sb`, `~/Jellyfin`, `~/Pictures/Wallpapers`.
  - `/var/lib/libvirt/images/win11.qcow2` (the Windows VM disk) and any other
    `/var/lib` service data you want to keep.
- Write the ISO to the stick (`dd if=nixos-*.iso of=/dev/sdX bs=4M
  status=progress oflag=sync`, or drop it on a Ventoy stick) and boot it in
  **UEFI** mode — `boot.loader.efi.canTouchEfiVariables` needs
  `/sys/firmware/efi`.

## 1. Create the filesystem (live ISO)

```bash
parted /dev/nvme0n1 -- mklabel gpt
parted /dev/nvme0n1 -- mkpart ESP fat32 1MiB 1GiB
parted /dev/nvme0n1 -- set 1 esp on
parted /dev/nvme0n1 -- mkpart primary btrfs 1GiB 100%

mkfs.fat -F 32 -n boot /dev/nvme0n1p1
mkfs.btrfs -L nixos /dev/nvme0n1p2

mount /dev/nvme0n1p2 /mnt
btrfs subvolume create /mnt/@{,home,nix,log}
btrfs subvolume set-default "$(btrfs subvolume list /mnt | awk '$NF=="@"{print $2}')" /mnt
umount /mnt

O="compress=zstd:3,noatime,ssd,discard=async"
mount -o "$O,subvol=@"    /dev/nvme0n1p2 /mnt
mkdir -p /mnt/{home,nix,var/log,boot}
mount -o "$O,subvol=@home" /dev/nvme0n1p2 /mnt/home
mount -o "$O,subvol=@nix"  /dev/nvme0n1p2 /mnt/nix
mount -o "$O,subvol=@log"  /dev/nvme0n1p2 /mnt/var/log
mount /dev/nvme0n1p1 /mnt/boot

lsblk -f   # note the btrfs UUID and the ESP UUID
```

## 2. Clone the flake and fill in the UUIDs

```bash
nix-shell -p git --run \
  'git clone https://github.com/alessandromalacarne/nixos.git /mnt/home/alsoasnerd/.config/nixos'

install -D -m600 /path/to/backup/keys.txt \
  /mnt/home/alsoasnerd/.config/sops/age/keys.txt
chown -R 1000:100 /mnt/home/alsoasnerd
```

In `/mnt/home/alsoasnerd/.config/nixos/modules/storage/filesys.nix`, replace:

- `REPLACE-WITH-BTRFS-UUID` with the `nvme0n1p2` UUID,
- `REPLACE-WITH-ESP-UUID` with the `nvme0n1p1` UUID.

## 3. Regenerate the hardware module

```bash
nixos-generate-config --root /mnt
```

Then copy only the **hardware** parts of `/mnt/etc/nixos/hardware-configuration.nix`
into the repo's `hardware-configuration.nix` (`boot.initrd.availableKernelModules`,
`boot.kernelModules`, `networking.useDHCP`, `nixpkgs.hostPlatform`, microcode) and
keep the repo's `fileSystems` / `swapDevices` out of it — `modules/storage/filesys.nix`
owns the mounts, and two definitions of `fileSystems."/"` with different devices
make evaluation fail.

## 4. Install

```bash
nixos-install --root /mnt --no-root-passwd \
  --flake /mnt/home/alsoasnerd/.config/nixos#nixos
nixos-enter --root /mnt -c 'passwd alsoasnerd'
```

`--no-root-passwd` is fine because `alsoasnerd` is in `wheel`; the `passwd` call is
needed because no password is declared for that user in the config.

## 5. After first boot

- `nh os switch` / `sudo nixos-rebuild switch --impure --flake .#nixos` to confirm
  the flake evaluates from the new system.
- `btrfs filesystem usage /` and `compression` check:
  `btrfs filesystem du -s /nix/store | tail -1` versus `du -sh /nix/store`.
- Restore the backed-up data that is not managed by home-manager.
