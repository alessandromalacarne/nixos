{ pkgs, ... }:

let
  unstable = import <nixos-unstable> {
    config = {
      allowUnfree = true;
    };
  };
in
{
  systemd.user.timers = {
    moodle = {
      Unit.Description = "Moodle Timer";
      Timer = {
        OnBootSec = "5m";
        OnUnitActiveSec = "5m";
        Unit = "moodle.service";
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };

  systemd.user.services = {
    moodle = {
      Unit = {
        Description = "Moodle Service";
      };

      Service = {
        Type = "oneshot";
        WorkingDirectory = "/home/alsoasnerd/Documents/moodle";
        ExecStart = "${pkgs.coreutils}/bin/env moodle-dl";
        StandardOutput = "null";
        StandardError = "null";
      };
    };

    jellyfin = {
      Install = {
        WantedBy = [ "default.target" ];
      };
      Unit = {
        After = [ "network-online.target" ];
        Wants = [ "network-online.target" ];
      };

      Service = {
        Type = "simple";
        ExecStart = "${pkgs.jellyfin}/bin/jellyfin --datadir /home/alsoasnerd/Jellyfin/data --configdir /home/alsoasnerd/Jellyfin/config --cachedir /home/alsoasnerd/.cache/jellyfin";
        Restart = "on-failure";
      };
    };
  };

  nixpkgs.config.permittedInsecurePackages = [
    "electron-33.4.11"
    "electron-36.9.5"
  ];

  services.gammastep = {
    enable = true;
    provider = "manual";
    latitude = -21.75;
    longitude = -43.35;

    temperature = {
      day = 6500;
      night = 2400;
    };

    settings = {
      general = {
        brightness-day = 1.0;
        brightness-night = 0.7;
        fade = 1;
        gamma = 0.9;
      };
    };
  };

  home.packages = with pkgs; [
    git
    gitflow
    act
    fzf
    bat
    eza
    wget
    alacritty
    tmux
    codeium
    tmux-sessionizer
    brave
    discord
    keepassxc
    unarc
    zsh
    starship
    via
    htop
    unzip
    sxhkd
    betterlockscreen
    obsidian
    sshfs
    xournalpp
    ripgrep
    ast-grep
    mpv
    playerctl
    pavucontrol
    alsa-utils
    gh

    feishin
    jellyfin
    jellyfin-web
    jellyfin-media-player
    jellyfin-ffmpeg
    qbittorrent

    rclone
    # libreoffice-fresh
    rar

    # taskwarrior2
    # timewarrior
    python3
    podman-compose
    moodle-dl
    tradingview

    luarocks
    pdftk
    picard
    lrcget
    jack2

    heroic

    sqlite
    btop-cuda
    feh
    # retroarch-full
    conky
    nautilus

    # Music
    p7zip

    gnutls
    nodejs
    typescript
    babashka
    jq

    obs-studio
    libreoffice-fresh

    dust

    fzf
    unstable.awscli2
    evtest

    bubblewrap
    steam
    cemu

    (writeShellScriptBin "Maya" ''
      API_PORT=7777 ROCKET_ADDRESS=0.0.0.0 MayaAPI
    '')
  ];

  # Set Nautilus as default file manager
  xdg.mimeApps.enable = true;
  xdg.mimeApps.defaultApplications = {
    "inode/directory" = "org.gnome.Nautilus.desktop";
  };
}
