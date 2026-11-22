# Reinstall `nixos` on btrfs

Runbook for wiping `nvme0n1` and reinstalling from the flake with btrfs
subvolumes instead of the single ext4 root.

Layout after this runbook:

| Partition     | Size | FS    | Mount        |
| ------------- | ---- | ----- | ------------ |
| `nvme0n1p1`   | 1G   | vfat  | `/boot` ESP  |
| `nvme0n1p2`   | rest | btrfs | subvolumes   |

Subvolumes on `nvme0n1p2`: `@` → `/`, `@home` → `/home`, `@nix` → `/nix`,
`@log` → `/var/log`. All mounted with `compress=zstd:3,noatime`.

No swap partition: `zramSwap` is enabled and hibernation is not configured.
No LUKS, no snapper.

## 0. What you need at hand

- The NixOS ISO on a stick (`dd if=nixos-*.iso of=/dev/sdX bs=4M
  status=progress oflag=sync`, or drop it on a Ventoy stick).
- The backup of `~/.config/sops/age/keys.txt`. Without it the sops secrets
  (and the `jiwolfsly`/`dummy` passwords) are unreadable.
- Whatever else you want back: `~/.ssh/id_ed25519*` and `allowed_signers`,
  `~/.secrets/agents`, `~/.local/share/ai-memory`, `~/projects`,
  `~/Documents/sb`, `~/Jellyfin`, `~/Pictures/Wallpapers`,
  `/var/lib/libvirt/images/win11.qcow2`, other `/var/lib` service state.
- The flake is on **`develop`**; `master` is a different lineage and does not
  contain the btrfs config. The clone below pins the branch.

## 1. Boot the live ISO

Boot in **UEFI** mode — `boot.loader.efi.canTouchEfiVariables` needs
`/sys/firmware/efi`:

```bash
[ -d /sys/firmware/efi ] && echo UEFI || echo "booted in BIOS mode, reboot"
```

Get network (needed for the clone and the binary cache):

```bash
nmtui          # or: iwctl, then systemctl start NetworkManager
ping -c1 cache.nixos.org
```

Identify the target disk and the backup stick:

```bash
lsblk -f
```

## 2. Create the filesystem

Everything on `nvme0n1` is destroyed from here on.

```bash
parted -s /dev/nvme0n1 mklabel gpt
parted -s /dev/nvme0n1 mkpart ESP fat32 1MiB 1GiB
parted -s /dev/nvme0n1 set 1 esp on
parted -s /dev/nvme0n1 mkpart primary btrfs 1GiB 100%

mkfs.fat -F 32 -n boot /dev/nvme0n1p1
mkfs.btrfs -L nixos /dev/nvme0n1p2

mount /dev/nvme0n1p2 /mnt
btrfs subvolume create /mnt/@{,home,nix,log}
btrfs subvolume set-default "$(btrfs subvolume list /mnt | awk '$NF=="@"{print $2}')" /mnt
umount /mnt

O="compress=zstd:3,noatime"
mount -o "$O,subvol=@"     /dev/nvme0n1p2 /mnt
mkdir -p /mnt/{home,nix,var/log,boot}
mount -o "$O,subvol=@home" /dev/nvme0n1p2 /mnt/home
mount -o "$O,subvol=@nix"  /dev/nvme0n1p2 /mnt/nix
mount -o "$O,subvol=@log"  /dev/nvme0n1p2 /mnt/var/log
mount /dev/nvme0n1p1 /mnt/boot

findmnt -R /mnt
```

## 3. Clone the flake and put the sops key in place

```bash
mkdir -p /backup && mount /dev/<backup-stick>1 /backup

mkdir -p /mnt/home/alsoasnerd/.config
nix-shell -p git --run \
  'git clone -b develop https://github.com/alessandromalacarne/nixos.git \
     /mnt/home/alsoasnerd/.config/nixos'

install -D -m600 /backup/keys.txt \
  /mnt/home/alsoasnerd/.config/sops/age/keys.txt
```

The clone and the key are root-owned at this point; ownership is fixed in
step 5, after the install has created the user accounts. sops-nix runs as root
during `nixos-install`, so it can read the key regardless.

## 4. Fill in the device UUIDs

```bash
cd /mnt/home/alsoasnerd/.config/nixos
sed -i "s|REPLACE-WITH-BTRFS-UUID|$(blkid -s UUID -o value /dev/nvme0n1p2)|" \
  modules/storage/filesys.nix
sed -i "s|REPLACE-WITH-ESP-UUID|$(blkid -s UUID -o value /dev/nvme0n1p1)|" \
  modules/storage/filesys.nix
grep by-uuid modules/storage/filesys.nix
```

## 5. Regenerate the hardware module, install

```bash
nixos-generate-config --root /mnt

cp /mnt/etc/nixos/hardware-configuration.nix \
   /mnt/home/alsoasnerd/.config/nixos/hardware-configuration.nix
```

In that copy, delete the generated `fileSystems = { … };` block and the
`swapDevices` line. `modules/storage/filesys.nix` owns the mounts; two
definitions of `fileSystems."/"` with different devices fail evaluation. Keep
`boot.initrd.availableKernelModules`, `boot.kernelModules`, `networking.useDHCP`,
`nixpkgs.hostPlatform` and the microcode line.

```bash
nixos-install --root /mnt --no-root-passwd \
  --flake /mnt/home/alsoasnerd/.config/nixos#nixos

nixos-enter --root /mnt -c \
  'chown -R alsoasnerd:users /home/alsoasnerd && passwd alsoasnerd'
```

`nixos-install` runs the new system's activation inside `nixos-enter`
(`switch-to-configuration boot`), which is why the sops key has to be in place
before this step. `--no-root-passwd` is fine because `alsoasnerd` is in `wheel`;
the `passwd` call is needed because no password is declared for that user.

The users have no explicit `uid`, so a fresh install assigns 1000 and up in
alphabetical order: `alsoasnerd` stays 1000, but `dmyna`/`dummy`/`jiwolfsly`/
`public` land on different numbers than today. Re-`chown` restored data that was
copied with numeric owners.

```bash
umount -R /mnt
reboot
```

Remove the stick. If the firmware does not offer the new entry, the ESP has
`EFI/BOOT/BOOTX64.EFI` as fallback.

## 6. First boot

- Log in as `alsoasnerd` with the password set in step 5.
- `sudo nixos-rebuild switch --impure --flake .#nixos` (or `nh os switch`) to
  confirm the flake evaluates from the new system.
- `btrfs filesystem usage /` and a compression sanity check:
  `btrfs filesystem du -s /nix/store` versus `du -sh /nix/store`.
- `sudo tailscale up` — the machine key is new, so the node re-registers.
- SSH host keys are regenerated: drop the old `known_hosts` entries on the
  machines that reach this host.

## 7. Restore data

Disable COW **before** restoring the COW-hostile data — `btrfs(5)` applies
`nodatacow` filesystem-wide from the first mounted subvolume, so it cannot be a
per-subvolume mount option; the inode attribute is the only lever:

```bash
sudo chattr +C /var/lib/libvirt/images      # before the qcow2 files exist
sudo chattr +C /var/lib/postgresql          # databases
sudo chattr +C /var/lib/containers/storage  # podman overlay storage
```

Then restore `~/projects`, `~/Documents/sb`, `~/Jellyfin`, the libvirt domain
XML plus `win11.qcow2`, and any other service state, and fix ownership:

```bash
sudo chown -R alsoasnerd:users /home/alsoasnerd
```
