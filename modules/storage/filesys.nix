{ ... }:
{

    fileSystems."/" = {
	device = "/dev/disk/by-uuid/65bfbba0-1211-4142-b9ea-c729857c304a";
	fsType = "ext4";
    };
    fileSystems."/boot" = {
	device = "/dev/disk/by-uuid/C68A-5DBE";
	fsType = "vfat";
	options = [ "fmask=0077" "dmask=0077" ];
    };
    fileSystems."/tmp" = {
	device = "tmpfs";
	fsType = "tmpfs";
	options = [ "size=8G" "mode=1777" ];
    };
}
