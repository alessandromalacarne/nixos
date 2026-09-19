{ pkgs, ... }:

{
  programs.virt-manager.enable = true;
  users.groups.libvirtd.members = [
    "alsoasnerd"
    "jiwolfsly"
  ];
  virtualisation.libvirtd.enable = true;
  virtualisation.libvirtd.qemu.vhostUserPackages = with pkgs; [
    virtiofsd
  ];
  virtualisation.spiceUSBRedirection.enable = true;

  virtualisation = {
    podman = {
      enable = true;
      autoPrune.enable = true;
      defaultNetwork.settings.dns_enabled = true;
    };
    oci-containers.backend = "podman";
  };

  hardware.nvidia-container-toolkit.enable = true;

  networking.firewall.interfaces."podman+".allowedUDPPorts = [ 53 ];
}
