{
  config,
  pkgs,
  lib,
  ...
}:
let
  # ============================================================
  # CONFIGURATION — edit only this block
  # ============================================================
  user = "alsoasnerd";
  lockHour = 22; # 24h — sudo restricted + sessions locked at this hour
  unlockHour = 6; # 24h — sudo re-enabled at this hour
  # Warning offsets in minutes before lockHour (must be multiples of timerInterval)
  warnFinal = 5; # final warning (minutes before lockHour)
  warnEarly = 15; # early warning (minutes before lockHour)
  timerInterval = 5; # how often the service fires (minutes)
  # ============================================================

  lockHourStr = builtins.toString lockHour;
  unlockHourStr = builtins.toString unlockHour;
  warnFinalMin = builtins.toString (60 - warnFinal); # e.g. 55
  warnEarlyMin = builtins.toString (60 - warnEarly); # e.g. 45
  warnHour = builtins.toString (lockHour - 1); # e.g. 21

  stateDir = "/var/lib/ulysses-pact";

in
{
  # ==========================================
  # LAYER 1 — FOUNDATION
  # ==========================================
  environment.systemPackages = [
    pkgs.libnotify
    pkgs.gawk
    pkgs.kdePackages.kdialog
  ];

  services.timesyncd.enable = true;

  # Ensure state directory exists with correct permissions.
  systemd.tmpfiles.rules = [
    "d ${stateDir} 0700 root root -"
  ];

  # ==========================================
  # LAYER 3 — TIMER
  # ==========================================
  systemd.timers.ulysses-pact = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "1min";
      OnUnitActiveSec = "${builtins.toString timerInterval}min";
      Persistent = true;
    };
    unitConfig.RefuseManualStop = true;
  };

  # ==========================================
  # LAYER 4 — ENFORCEMENT SERVICE
  # ==========================================
  systemd.services.ulysses-pact = {
    description = "Ulysses Pact — time-based session lock + sudo restriction";

    unitConfig = {
      RefuseManualStop = true;
      RefuseManualStart = true;
    };

    serviceConfig = {
      Type = "oneshot";
      Restart = "on-failure";
      RestartSec = "15s";

      # ── Sandbox ───────────────────────────────────────────────────
      ProtectSystem = "true";
      ProtectHome = "read-only";
      PrivateTmp = true;
      NoNewPrivileges = true;
      RestrictNamespaces = true;
      LockPersonality = true;
      # MemoryDenyWriteExecute is intentionally omitted:
      # bash uses executable stack trampolines and will crash with it.
      # ──────────────────────────────────────────────────────────────

      ExecStart = pkgs.writeShellScript "ulysses-pact" ''
        set -uo pipefail

        USER="${user}"
        USER_ID=$(${pkgs.coreutils}/bin/id -u "$USER")
        HOUR=$(${pkgs.coreutils}/bin/date +%H)
        MIN=$(${pkgs.coreutils}/bin/date +%M)
        STATE_DIR="${stateDir}"

        # GUI helpers run as root, so they don't inherit the compositor's
        # environment. Ask the user's systemd manager for the display vars
        # instead of guessing: niri binds wayland-1, not wayland-0, so an
        # unset WAYLAND_DISPLAY makes kdialog fail to connect.
        GUI_ENV=()
        while IFS= read -r kv; do
          case "$kv" in
            WAYLAND_DISPLAY=* | DISPLAY=*) GUI_ENV+=("$kv") ;;
          esac
        done < <(
          ${pkgs.util-linux}/bin/runuser -u "$USER" -- \
            env XDG_RUNTIME_DIR="/run/user/$USER_ID" \
            ${pkgs.systemd}/bin/systemctl --user show-environment 2>/dev/null || true
        )

        # Run a command as the target user with D-Bus access.
        # The systemd user bus socket is always at /run/user/$UID/bus
        # on systemd-managed desktops — no need to discover via /proc.
        # runuser comes from util-linux, which is NOT part of the unit's
        # default PATH, so it must be referenced by store path.
        as_user() {
          ${pkgs.util-linux}/bin/runuser -u "$USER" -- \
            env \
              XDG_RUNTIME_DIR="/run/user/$USER_ID" \
              DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$USER_ID/bus" \
              "''${GUI_ENV[@]}" \
            "$@"
        }

        # ── Helpers ──────────────────────────────────────────────────

        notify() {
          # $1: urgency (low|normal|critical)  $2: message
          as_user ${pkgs.libnotify}/bin/notify-send \
            --urgency="$1" --expire-time=0 "Ulysses Pact" "$2"
        }

        popup() {
          # kdialog --msgbox blocks until dismissed. Cap it, otherwise an
          # unattended dialog keeps the oneshot active past the lock hour
          # and the timer never fires the night-mode run.
          as_user ${pkgs.coreutils}/bin/timeout 120 \
            ${pkgs.kdePackages.kdialog}/bin/kdialog \
            --title "Ulysses Pact" --msgbox "$1"
        }

        # Emit a warning at most once per named window.
        # $1: window tag (e.g. "warn-early")  $2...: shell function to run.
        # The handler MUST be a function defined in this script: a separate
        # writeShellScript file runs in its own bash and cannot see
        # notify/popup. Only burn the flag once the handler actually ran.
        once_per_window() {
          local tag="$1"; shift
          local flag="$STATE_DIR/$tag"
          [ -f "$flag" ] && return 0
          if "$@"; then
            ${pkgs.coreutils}/bin/touch "$flag"
          else
            echo "ulysses-pact: '$tag' handler failed; retrying next tick" >&2
          fi
        }

        # Clear all warning flags (called on day-mode so next evening fires fresh).
        clear_flags() {
          ${pkgs.findutils}/bin/find "$STATE_DIR" -name 'warn-*' -delete || true
        }

        lock_user_sessions() {
          ${pkgs.systemd}/bin/loginctl list-sessions --no-legend \
            | ${pkgs.gawk}/bin/awk -v u="$USER" '$3 == u {print $1}' \
            | while read -r sid; do
                ${pkgs.systemd}/bin/loginctl lock-session "$sid" || true
              done
        }

        # ── Warning handlers ─────────────────────────────────────────
        # Defined as functions so once_per_window can call them in-process.

        warn_early() {
          notify normal "${builtins.toString warnEarly} minutes until lockout."
          popup "🕙 ${builtins.toString warnEarly} minutes until lockout. Start wrapping up."
        }

        warn_final() {
          notify critical "${builtins.toString warnFinal} minutes until lockout — save everything."
          popup "⏳ ${builtins.toString warnFinal} minutes until lockout. Wrap it up NOW."
        }

        # ── Time logic ───────────────────────────────────────────────

        if [ "$HOUR" -ge ${lockHourStr} ] || [ "$HOUR" -lt ${unlockHourStr} ]; then
          # ── NIGHT MODE ──────────────────────────────────────────
          lock_user_sessions

        elif [ "$HOUR" -eq ${warnHour} ] && [ "$MIN" -ge ${warnFinalMin} ]; then
          # ── FINAL WARNING (${builtins.toString warnFinal} min before lock) ────────
          once_per_window "warn-final" warn_final

        elif [ "$HOUR" -eq ${warnHour} ] && [ "$MIN" -ge ${warnEarlyMin} ]; then
          # ── EARLY WARNING (${builtins.toString warnEarly} min before lock) ─────────
          once_per_window "warn-early" warn_early

        else
          # ── DAY MODE ────────────────────────────────────────────
          clear_flags
        fi
      '';
    };
  };
}
