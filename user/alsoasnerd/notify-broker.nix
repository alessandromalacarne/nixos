{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Shared with the jail through the `~/.commandcode` rw_map in agents.nix,
  # so the sandboxed hook can reach a socket that lives on the host.
  socketPath = "${config.home.homeDirectory}/.commandcode/notify.sock";

  # Pinned to the store instead of /run/current-system so the service keeps
  # working even if the system profile changes under it.
  soundFile =
    "${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop/stereo/message-new-instant.oga";
in
{
  # The broker must run as the desktop user: it needs the session bus that the
  # niri session and noctalia own, which a system service would have to fake
  # with runuser + DBUS_SESSION_BUS_ADDRESS. A user unit inherits both.
  systemd.user.services.notify-broker = {
    Unit = {
      Description = "Notification broker for agent hooks running inside ai-jail";
    };

    Service = {
      Type = "simple";
      ExecStart = "${pkgs.python3}/bin/python3 ${./notify-broker.py}";

      # Absolute store paths keep the service independent of the user PATH;
      # the Python file reads all of them from here so it also stays runnable
      # from a test harness.
      Environment = [
        "NOTIFY_BROKER_SOCKET=${socketPath}"
        "NOTIFY_BROKER_NOTIFY_SEND=${pkgs.libnotify}/bin/notify-send"
        "NOTIFY_BROKER_PA_PLAY=${pkgs.pulseaudio}/bin/paplay"
        "NOTIFY_BROKER_SOUND_FILE=${soundFile}"
        "PYTHONUNBUFFERED=1"
      ];

      Restart = "on-failure";
      RestartSec = "2s";

      # The socket is the only authentication boundary (mode 0600).
      UMask = "0077";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      # D-Bus, PipeWire and the Unix socket itself all speak AF_UNIX. No
      # client of this broker needs TCP.
      RestrictAddressFamilies = [ "AF_UNIX" ];
    };

    Install.WantedBy = [ "default.target" ];
  };

  # Command Code owns ~/.commandcode/settings.json but not the hook scripts,
  # so install the wrapper directly instead of linking a store path: the
  # jail mounts the host store read-only and a copy survives GCs.
  home.activation.commandCodeNotifyHook = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD install -Dm0755 ${./dotfiles/commandcode/session-end-notify.sh} \
      ${config.home.homeDirectory}/.commandcode/hooks/session-end-notify.sh
  '';
}
