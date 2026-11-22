{ ... }:
let
  # UUID of the btrfs partition that holds the root filesystem.
  # Read it with `lsblk -f` in the live ISO after `mkfs.btrfs` and replace the
  # placeholder before running `nixos-install`.
  rootDevice = "/dev/disk/by-uuid/REPLACE-WITH-BTRFS-UUID";

  # btrfs(5): most mount options are filesystem-wide and the first mounted
  # subvolume wins, so compress/nodatacow must not differ between subvolumes.
  # `ssd` is autodetected and `discard=async` is the default since Linux 6.2,
  # so neither needs to be spelled out.
  btrfsOpts = [
    "compress=zstd:3"
    "noatime"
  ];

  # Subvolumes exist for rollback granularity: a snapshot of @ leaves /home,
  # /nix and /var/log untouched.
  subvolume = name: {
    device = rootDevice;
    fsType = "btrfs";
    options = btrfsOpts ++ [ "subvol=${name}" ];
  };
in
{
  fileSystems = {
    "/" = subvolume "@";
    "/home" = subvolume "@home";
    "/nix" = subvolume "@nix" // {
      neededForBoot = true;
    };
    "/var/log" = subvolume "@log" // {
      neededForBoot = true;
    };

    "/boot" = {
      # EFI system partition UUID, also printed by `lsblk -f`.
      device = "/dev/disk/by-uuid/REPLACE-WITH-ESP-UUID";
      fsType = "vfat";
      options = [ "fmask=0077" "dmask=0077" ];
    };
    "/tmp" = {
      device = "tmpfs";
      fsType = "tmpfs";
      options = [ "size=8G" "mode=1777" ];
    };
  };

  # Surface checksum errors early instead of discovering them on read.
  services.btrfs.autoScrub = {
    enable = true;
    interval = "weekly";
    fileSystems = [ "/" ];
  };
}
