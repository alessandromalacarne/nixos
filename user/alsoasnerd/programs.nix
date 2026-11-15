{ config, pkgs, ... }:

let
  unstable = import <nixos-unstable> {
    config = {
      allowUnfree = true;
    };
  };

  # gh reads GH_TOKEN from its environment. A static session variable only
  # holds the script path, so wrap gh instead and resolve a fresh token on
  # every invocation. Falling back to the real gh keeps auth errors visible
  # when the token endpoint is unavailable.
  clunkerToken = "${config.home.homeDirectory}/.local/bin/clunker-token.sh";
  ghWithToken = pkgs.writeShellScriptBin "gh" ''
    token="$(${clunkerToken} 2>/dev/null || true)"
    case "$token" in
      ""|"null") exec ${pkgs.gh}/bin/gh "$@" ;;
      *) exec env GH_TOKEN="$token" ${pkgs.gh}/bin/gh "$@" ;;
    esac
  '';
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
    libnotify
    ghWithToken

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
    worktrunk

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
