{ ... }:

{
  programs.virt-manager.enable = true;
  users.groups.libvirtd.members = [
    "alsoasnerd"
    "jiwolfsly"
  ];
  virtualisation.libvirtd.enable = true;
  virtualisation.spiceUSBRedirection.enable = true;

  virtualisation.docker.enable = true;
  hardware.nvidia-container-toolkit.enable = true;
}
