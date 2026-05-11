{ config, pkgs, lib, ... }:

let
  user = "alsoasnerd";
in
{
  # ==========================================
  # LAYER 1 — FOUNDATION
  # ==========================================
  environment.systemPackages = [
    pkgs.shadow
    pkgs.systemd
    pkgs.iproute2
    pkgs.procps
    pkgs.libnotify
    pkgs.alsa-utils
    pkgs.kdePackages.kdialog
  ];

  services.timesyncd.enable = true;

  # ==========================================
  # LAYER 2 — PAM (BLOCK ESCALATION)
  # ==========================================
  environment.etc."security/time.conf".text = ''
    sudo;su;*;${user};!Al2200-0800
  '';

  security.pam.services.sudo.text = lib.mkDefault (lib.mkAfter ''
    account required pam_time.so
  '');

  security.pam.services.su.text = ''
    account required pam_time.so
  '';

  security.polkit.enable = true;

  # ==========================================
  # LAYER 3 — HIGH-FREQUENCY TIMER
  # ==========================================
  systemd.timers.ulysses-pact = {
    wantedBy = [ "timers.target" ];

    timerConfig = {
      OnBootSec = "2min";
      OnUnitActiveSec = "5min";
      Persistent = true;
    };

    unitConfig = {
      RefuseManualStop = true;
    };
  };

  # ==========================================
  # LAYER 4 — ENFORCEMENT SERVICE
  # ==========================================
  systemd.services.ulysses-pact = {
    description = "Progressive discipline system with GUI alerts";

    unitConfig = {
      RefuseManualStop = true;
      RefuseManualStart = true;
    };

    serviceConfig = {
      Type = "oneshot";

      ExecStart = pkgs.writeShellScript "ulysses-pact" ''
        set -euo pipefail

        USER="${user}"
        USER_ID=$(${pkgs.coreutils}/bin/id -u "$USER")
        HOUR=$(${pkgs.coreutils}/bin/date +%H)

        DBUS_ADDR="unix:path=/run/user/$USER_ID/bus"

        notify() {
          runuser -u "$USER" -- env DBUS_SESSION_BUS_ADDRESS="$DBUS_ADDR" \
            ${pkgs.libnotify}/bin/notify-send "$1" "$2" || true
        }

        popup() {
          runuser -u "$USER" -- \
            ${pkgs.kdePackages.kdialog}/bin/kdialog --title "Ulysses Pact" --msgbox "$1" || true
        }

        sound() {
          runuser -u "$USER" -- \
            ${pkgs.alsa-utils}/bin/aplay /run/current-system/sw/share/sounds/alsa/Front_Center.wav || true
        }

        is_night() {
          [ "$HOUR" -ge 22 ] || [ "$HOUR" -lt 8 ]
        }

        # ==============================
        # DAY MODE (RESET)
        # ==============================
        if ! is_night; then
          ${pkgs.shadow}/bin/chage -E -1 "$USER"
          exit 0
        fi

        # ==============================
        # NIGHT MODE
        # ==============================
        
        if [ "$HOUR" -eq 21 ] && [ "$MIN" -ge 55 ]; then
          popup "💀 Locking your stuff... See you tomorrow! :)"
          sound
        fi

        # ==============================
        # HARD LOCK
        # ==============================
        ${pkgs.shadow}/bin/chage -E 0 "$USER"

        if ${pkgs.systemd}/bin/loginctl list-users | grep -q "$USER"; then
          ${pkgs.systemd}/bin/loginctl terminate-user "$USER" || true
        fi
      '';
    };
  };
}
