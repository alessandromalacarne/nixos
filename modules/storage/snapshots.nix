{ ... }:
let
  # Snapshots live in a plain directory inside the subvolume they snapshot, and
  # each snapshot is a nested subvolume in it. A btrfs snapshot never descends
  # into nested subvolumes, so a snapshot of @ leaves the snapshots of @home
  # alone and vice versa. The directory has to exist: btrbk does not create it.
  #
  # Each entry is `<subvolume-mountpoint>` -> `<snapshot directory>`.
  snapshotRoots = {
    "/" = "/.snapshots";
    "/home" = "/home/.snapshots";
  };
in
{
  # `run` creates snapshots and applies the retention policy. There is no
  # `target`, so nothing leaves this disk; add `target = "/run/media/<disk>"` to
  # a subvolume below to also push the snapshots to a USB disk with send/receive.
  #
  # Snapshot names carry the subvolume they belong to, so `btrfs subvolume list`
  # reads like the layout: @.20260101T0000, @home.20260101T0000.
  services.btrbk.instances.local = {
    onCalendar = "hourly";
    settings = {
      snapshot_preserve_min = "2d";
      snapshot_preserve = "14d 8w 6m";
      subvolume = {
        "/" = {
          snapshot_dir = snapshotRoots."/";
          snapshot_name = "@";
        };
        "/home" = {
          snapshot_dir = snapshotRoots."/home";
          snapshot_name = "@home";
        };
      };
    };
  };

  # tmpfiles runs at boot, after the subvolumes are mounted, and the mountpoint
  # is what btrbk resolves the subvolume from, so no btrfs call is needed here.
  systemd.tmpfiles.rules = map (dir: "d ${dir} 0700 root root -") (
    builtins.attrValues snapshotRoots
  );
}
