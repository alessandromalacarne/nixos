# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    # Toggle: nvidia.nix for PRIME offload (host uses dGPU),
    # gpu-passthrough.nix for VFIO passthrough to VM (host uses iGPU only).
    # Only one should be uncommented at a time
    ./modules/hardware/nvidia.nix
    # ./modules/hardware/gpu-passthrough.nix
    ./modules/hardware/audio.nix
    ./modules/hardware/virtualization.nix
    ./modules/hardware/bluetooth.nix
    ./modules/storage/filesys.nix
    ./modules/networking/networking.nix
    ./modules/services/servers.nix
    ./modules/services/spicetify.nix
    ./modules/services/agents.nix
    ./modules/services/ulysses.nix
    ./modules/services/syncthing.nix
    ./modules/services/nginx.nix
    ./modules/services/grimmory.nix
    ./modules/services/twenty.nix
    ./modules/services/pihole.nix
    # ./modules/services/ollama.nix
  ];

  nix = {
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 2d";
    };
    settings = {
      auto-optimise-store = true;
      experimental-features = [
        "nix-command"
        "flakes"
      ];

      substituters = [
        "https://cache.nixos.org"
        "https://nix-community.cachix.org"
      ];

      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];

      builders-use-substitutes = true;

      extra-sandbox-paths = [ "/var/cache/ccache" ];
    };
  };

  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandleLidSwitchExternalPower = "ignore";
    HandleLidSwitchDocked = "ignore";
  };
  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.supportedFilesystems = [ "ntfs" ];

  zramSwap = {
    enable = true;
    memoryPercent = 150;
    algorithm = "zstd";
  };

  systemd.oomd.enable = true;

  boot.kernel.sysctl = {
    "kern.elf32.aslr.stack" = "0";
    "kern.elf32.nxstack" = "0";
    "kern.elf64.aslr.stack" = "0";
    "kern.elf64.nxstack" = "0";
  };

  boot.extraModulePackages = with config.boot.kernelPackages; [
    v4l2loopback
  ];

  boot.extraModprobeConfig = ''
    options snd-hda-intel model=alc255-acer,dell-headset-multi,headset-mic
    options v4l2loopback devices=1 video_nr=1 card_label="OBS Cam" exclusive_caps=1
  '';

  boot.kernelParams = [
    "snd_hda_intel.dmic_detect=0"
    "snd-intel-dspcfg.dsp_driver=1"
  ];

  security.polkit.enable = true;

  sops.age.keyFile = "/home/alsoasnerd/.config/sops/age/keys.txt";
  sops.defaultSopsFile = ./secrets/users.yaml.sops;

  sops.secrets."users/jiwolfsly/initialPassword" = { };
  sops.secrets."users/dummy/initialPassword" = { };

  networking.hostName = "nixos"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "America/Sao_Paulo";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "pt_BR.UTF-8";
    LC_IDENTIFICATION = "pt_BR.UTF-8";
    LC_MEASUREMENT = "pt_BR.UTF-8";
    LC_MONETARY = "pt_BR.UTF-8";
    LC_NAME = "pt_BR.UTF-8";
    LC_NUMERIC = "pt_BR.UTF-8";
    LC_PAPER = "pt_BR.UTF-8";
    LC_TELEPHONE = "pt_BR.UTF-8";
    LC_TIME = "pt_BR.UTF-8";
  };

  # Enable the X11 windowing system.
  services.xserver.enable = true;
  # Enable wacom tablet
  # services.xserver.wacom.enable = true;
  services.xserver.windowManager.bspwm.enable = true;

  # services = {
  #   flatpak = {
  #     enable = true;
  #     remotes = lib.mkOptionDefault [
  #       {
  #         name = "flathub-beta";
  #         location = "https://flathub.org/beta-repo/flathub-beta.flatpakrepo";
  #       }
  #     ];
  #
  #     update.auto.enable = false;
  #     uninstallUnmanaged = false;
  #
  #     packages = [ "app.zen_browser.zen" ];
  #   };
  # };

  hardware.keyboard.qmk.enable = true;

  programs = {
    hyprland.enable = true;
    niri.enable = true;
    gamescope = {
      enable = true;
      capSysNice = true;
    };
    # gamemode = {
    #   enable = true;
    #
    #   settings = {
    #     general.defaltgov = "schedutil";
    #     general.desiredgov = "performance";
    #   };
    # };
    opengamepadui = {
      enable = true;
      inputplumber.enable = true;
      powerstation.enable = true;
      gamescopeSession.enable = true;
    };
    # steam = {
    #   enable = true;
    #   gamescopeSession.enable = true;
    # };
    nix-ld = {
      enable = true;
    };
  };

  # Login manager: greetd + tuigreet (works with Wayland compositors like niri)
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --cmd niri-session";
        user = "greeter";
      };
    };
  };

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "altgr-intl";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable touchpad support (enabled default in most desktopManager).
  services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users = {
    public = {
      isNormalUser = true;
      description = "Public User";
      extraGroups = [ "networkmanager" ];
      shell = pkgs.zsh;
    };
    alsoasnerd = {
      isNormalUser = true;
      description = "alsoasnerd";
      extraGroups = [
        "networkmanager"
        "wheel"
        "audio"
        "video"
        "render"
        "podman"
      ];
      shell = pkgs.zsh;
    };
    jiwolfsly = {
      isNormalUser = true;
      description = "jiwolfsly";
      extraGroups = [
        "networkmanager"
        "wheel"
        "audio"
        "podman"
      ];
      shell = pkgs.zsh;
    };
    dmyna = {
      isNormalUser = true;
      description = "dmyna";
      extraGroups = [
        "networkmanager"
        "wheel"
        "audio"
        "podman"
        "gamemode"
      ];
      shell = pkgs.zsh;
    };
    dummy = {
      isNormalUser = true;
      description = "Dummy User";
      extraGroups = [
        "networkmanager"
        "wheel"
      ];
      shell = pkgs.zsh;
    };
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  fonts.packages = with pkgs; [
    cascadia-code
    ipafont
    inter
  ];

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
  };

  environment.systemPackages = with pkgs; [
    inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default
    xwayland-satellite
    mangohud
    gamemode
    appimage-run

    tailscale
    coreutils
    openssl
    searxng
    pulseaudio
    neovim
    spotify
    lsof

    veracrypt

    zsh

    nh
    home-manager
  ];

  services.searx = {
    enable = true;
    settings = {
      server = {
        port = 8888;
        bind_address = "0.0.0.0";
        secret_key = "${pkgs.searxng}";
      };
    };
  };

  programs = {
    zsh = {
      enable = true;
      syntaxHighlighting.enable = true;
      autosuggestions.enable = true;
      histSize = 100000;
    };
  };
  programs.dconf.enable = true;

  # XDG Desktop Portal for file dialogs (needed by Brave, Nautilus, etc. on Wayland)
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config = {
      common = {
        default = [ "gtk" ];
      };
    };
  };

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  programs.gnupg.agent.enableSSHSupport = true;
  programs.ssh.startAgent = true;

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = true;
      AllowUsers = null;
      X11Forwarding = true;
    };
  };
  services.tailscale.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?
}
