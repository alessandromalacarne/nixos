{ ... }:
let
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
  subvolume = mountpoint: {
    inherit mountpoint;
    mountOptions = btrfsOpts;
  };
in
{
  # This layout is both the install plan and the running configuration.
  # disko generates fileSystems from the mountpoints and addresses every
  # partition by its GPT label, so nothing here depends on a filesystem UUID:
  # a reformat cannot leave the config pointing at a filesystem that no
  # longer exists, and no placeholder has to be filled in by hand.
  #
  # `device` is only read by the destructive scripts (destroy/format). The
  # running system resolves every mount through /dev/disk/by-partlabel.
  disko.devices.disk.main = {
    type = "disk";
    device = "/dev/nvme0n1";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          name = "ESP";
          label = "nixos-boot";
          size = "1G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "fmask=0077" "dmask=0077" ];
          };
        };
        root = {
          name = "root";
          label = "nixos-root";
          size = "100%";
          content = {
            type = "btrfs";
            subvolumes = {
              "@" = subvolume "/";
              "@home" = subvolume "/home";
              "@nix" = subvolume "/nix";
              "@log" = subvolume "/var/log";
            };
          };
        };
      };
    };
  };

  # disko does not express these: a tmpfs, and the mounts stage 1 needs
  # before /nix exists for the rest of the boot.
  fileSystems."/tmp" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [ "size=8G" "mode=1777" ];
  };
  fileSystems."/nix".neededForBoot = true;
  fileSystems."/var/log".neededForBoot = true;

  # Surface checksum errors early instead of discovering them on read.
  services.btrfs.autoScrub = {
    enable = true;
    interval = "weekly";
    fileSystems = [ "/" ];
  };

  # btrfs applies COW per inode and new files inherit the attribute, so it has
  # to be set on the directory before the first qcow2 exists. The `d` line is
  # required: `h` adjusts a path, it does not create one.
  systemd.tmpfiles.rules = [
    "d /var/lib/libvirt/images - - - -"
    "h /var/lib/libvirt/images - - - +C"
  ];
}
