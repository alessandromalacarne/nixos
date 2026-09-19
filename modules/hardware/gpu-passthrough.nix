{
  config,
  pkgs,
  lib,
  ...
}:

{
  # GPU: NVIDIA GTX 1650 Mobile (10de:1f99)
  # Audio: NVIDIA HDMI (10de:10fa)
  # Both in IOMMU group 9 — clean isolation from host (AMD iGPU).

  boot.kernelParams = [
    "amd_iommu=on" # already on by default on AMD, explicit
    "iommu=pt" # pass-through translation, better perf
    "vfio-pci.ids=10de:1f99,10de:10fa"
    "isolcpus=2-9" # isolate VM cores from host scheduler
  ];

  # Load VFIO in initrd so it claims the GPU before nvidia/nouveau can bind.
  boot.initrd.kernelModules = [
    "vfio_pci"
    "vfio"
    "vfio_iommu_type1"
  ];

  boot.kernelModules = [
    "vfio"
    "vfio_iommu_type1"
    "kvmfr"
  ];

  # kvm.ignore_msrs=1: Windows games read unknown MSRs, without this they crash.
  # kvm.report_ignored_msrs=0: stops kernel log spam from the above.
  boot.extraModprobeConfig = ''
    options vfio-pci ids=10de:1f99,10de:10fa
    softdep nvidia pre: vfio-pci
    softdep nvidia_modeset pre: vfio-pci
    softdep nvidia_drm pre: vfio-pci
    options kvmfr static_size_mb=64
    options kvm ignore_msrs=1
    options kvm report_ignored_msrs=0
  '';

  # Looking Glass kernel module (from nixpkgs).
  boot.extraModulePackages = [ config.boot.kernelPackages.kvmfr ];

  # Hugepages — 8 GB for VM + GPU DMA, fewer TLB misses.
  boot.kernel.sysctl."vm.nr_hugepages" = 4096;

  # Force performance governor — laptop powersave kills VM throughput.
  powerManagement.cpuFreqGovernor = "performance";

  # nvidia-container-toolkit from virtualization.nix asserts driver exists.
  hardware.nvidia-container-toolkit.suppressNvidiaDriverAssertion = true;
  systemd.services.nvidia-container-toolkit-cdi-generator.enable = false;

  # Libvirt QEMU tuning for PCI passthrough.
  virtualisation.libvirtd.qemu = {
    swtpm.enable = true;
    runAsRoot = true;
    package = pkgs.qemu_kvm;
    verbatimConfig = ''
      cgroup_device_acl = [
          "/dev/null", "/dev/full", "/dev/zero",
          "/dev/random", "/dev/urandom",
          "/dev/ptmx", "/dev/kvm",
          "/dev/kvmfr0"
      ]
    '';
  };

  # Add libvirtd user to necessary groups.
  users.users.alsoasnerd.extraGroups = [
    "libvirtd"
    "kvm"
  ];

  # Ensure VFIO + kvmfr devices are accessible.
  services.udev.extraRules = ''
    SUBSYSTEM=="vfio", OWNER="root", GROUP="kvm", MODE="0660"
    SUBSYSTEM=="kvmfr", OWNER="alsoasnerd", GROUP="kvm", MODE="0660"
  '';

  # Looking Glass client
  environment.systemPackages = with pkgs; [ looking-glass-client ];
}
