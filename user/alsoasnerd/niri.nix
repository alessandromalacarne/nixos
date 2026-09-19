{
  pkgs,
  config,
  inputs,
  ...
}:
let
  noctalia = inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
{
  programs.niri = {
    package = inputs.niri-flake.packages.${pkgs.stdenv.hostPlatform.system}.niri-unstable;
    settings = {
      input = {
        mod-key = "Alt";
        mod-key-nested = "Super";
        keyboard.xkb = {
          layout = "us";
          variant = "altgr-intl";
        };
        touchpad = {
          tap = true;
          natural-scroll = true;
        };
      };

      layout = {
        gaps = 12;
        center-focused-column = "never";
        preset-column-widths = [
          { proportion = 0.33333; }
          { proportion = 0.5; }
          { proportion = 0.66667; }
        ];
        default-column-width = {
          proportion = 0.5;
        };
        focus-ring = {
          width = 4;
          active.color = "#7fc8ff";
          inactive.color = "#505050";
        };
        border.enable = false;
        shadow.enable = false;
      };

      spawn-at-startup = [
        { command = [ "${noctalia}/bin/noctalia" ]; }
      ];

      hotkey-overlay.skip-at-startup = true;
      prefer-no-csd = true;
      screenshot-path = "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png";

      window-rules = [
        {
          matches = [ { app-id = "^org\\.wezfurlong\\.wezterm$"; } ];
          default-column-width = { };
        }
        {
          matches = [
            {
              app-id = "firefox$";
              title = "^Picture-in-Picture$";
            }
          ];
          open-floating = true;
        }
      ];

      binds = with config.lib.niri.actions; {
        "Mod+Shift+Slash".action = show-hotkey-overlay;

        "Mod+BackSpace".action.spawn = [ "alacritty" ];
        "Mod+Space".action.spawn = [ "fuzzel" ];
        "Super+L".action.spawn = [
          "noctalia"
          "msg"
          "session"
          "lock"
        ];

        "XF86AudioRaiseVolume".action.spawn-sh = [ "wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1+ -l 1.0" ];
        "XF86AudioLowerVolume".action.spawn-sh = [ "wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1-" ];
        "XF86AudioMute".action.spawn-sh = [ "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle" ];
        "XF86AudioMicMute".action.spawn-sh = [ "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle" ];

        "XF86AudioPlay".action.spawn = [
          "playerctl"
          "play-pause"
        ];
        "XF86AudioPause".action.spawn = [
          "playerctl"
          "play-pause"
        ];
        "XF86AudioStop".action.spawn = [
          "playerctl"
          "stop"
        ];
        "XF86AudioPrev".action.spawn = [
          "playerctl"
          "previous"
        ];
        "XF86AudioNext".action.spawn = [
          "playerctl"
          "next"
        ];

        "XF86MonBrightnessUp".action.spawn = [
          "brightnessctl"
          "--class=backlight"
          "set"
          "+10%"
        ];
        "XF86MonBrightnessDown".action.spawn = [
          "brightnessctl"
          "--class=backlight"
          "set"
          "10%-"
        ];

        "Mod+O" = {
          action = toggle-overview;
          repeat = false;
        };
        "Mod+C" = {
          action = close-window;
          repeat = false;
        };

        "Mod+Left".action = focus-column-left;
        "Mod+Down".action = focus-window-down;
        "Mod+Up".action = focus-window-up;
        "Mod+Right".action = focus-column-right;
        "Mod+H".action = focus-column-left;
        "Mod+J".action = focus-window-down;
        "Mod+K".action = focus-window-up;
        "Mod+L".action = focus-column-right;

        "Shift+Left".action = move-column-left;
        "Shift+Down".action = move-window-down;
        "Shift+Up".action = move-window-up;
        "Shift+Right".action = move-column-right;

        "Mod+Home".action = focus-column-first;
        "Mod+End".action = focus-column-last;
        "Mod+Ctrl+Home".action = move-column-to-first;
        "Mod+Ctrl+End".action = move-column-to-last;

        "Mod+Page_Down".action = focus-workspace-down;
        "Mod+Page_Up".action = focus-workspace-up;

        "Mod+Ctrl+Page_Down".action = move-column-to-workspace-down;
        "Mod+Ctrl+Page_Up".action = move-column-to-workspace-up;

        "Mod+Shift+Page_Down".action = move-workspace-down;
        "Mod+Shift+Page_Up".action = move-workspace-up;

        "Mod+WheelScrollDown" = {
          action = focus-workspace-down;
          cooldown-ms = 150;
        };
        "Mod+WheelScrollUp" = {
          action = focus-workspace-up;
          cooldown-ms = 150;
        };
        "Mod+Ctrl+WheelScrollDown" = {
          action = move-column-to-workspace-down;
          cooldown-ms = 150;
        };
        "Mod+Ctrl+WheelScrollUp" = {
          action = move-column-to-workspace-up;
          cooldown-ms = 150;
        };

        "Mod+1".action.focus-workspace = [ 1 ];
        "Mod+2".action.focus-workspace = [ 2 ];
        "Mod+3".action.focus-workspace = [ 3 ];
        "Mod+4".action.focus-workspace = [ 4 ];
        "Mod+5".action.focus-workspace = [ 5 ];
        "Mod+6".action.focus-workspace = [ 6 ];
        "Mod+7".action.focus-workspace = [ 7 ];
        "Mod+8".action.focus-workspace = [ 8 ];
        "Mod+9".action.focus-workspace = [ 9 ];

        "Mod+Ctrl+1".action.move-column-to-workspace = [ 1 ];
        "Mod+Ctrl+2".action.move-column-to-workspace = [ 2 ];
        "Mod+Ctrl+3".action.move-column-to-workspace = [ 3 ];
        "Mod+Ctrl+4".action.move-column-to-workspace = [ 4 ];
        "Mod+Ctrl+5".action.move-column-to-workspace = [ 5 ];
        "Mod+Ctrl+6".action.move-column-to-workspace = [ 6 ];
        "Mod+Ctrl+7".action.move-column-to-workspace = [ 7 ];
        "Mod+Ctrl+8".action.move-column-to-workspace = [ 8 ];
        "Mod+Ctrl+9".action.move-column-to-workspace = [ 9 ];

        "Mod+BracketLeft".action = consume-or-expel-window-left;
        "Mod+BracketRight".action = consume-or-expel-window-right;
        "Mod+Comma".action = consume-window-into-column;
        "Mod+Period".action = expel-window-from-column;

        "Mod+R".action = switch-preset-column-width;
        "Mod+Shift+R".action = switch-preset-column-width-back;
        "Mod+Ctrl+Shift+R".action = switch-preset-window-height;
        "Mod+Ctrl+R".action = reset-window-height;

        "Mod+F".action = maximize-column;
        "Mod+Shift+F".action = fullscreen-window;
        "Mod+Ctrl+F".action = expand-column-to-available-width;
        "Mod+Ctrl+C".action = center-visible-columns;

        "Mod+Minus".action.set-column-width = [ "-10%" ];
        "Mod+Equal".action.set-column-width = [ "+10%" ];
        "Mod+Shift+Minus".action.set-window-height = [ "-10%" ];
        "Mod+Shift+Equal".action.set-window-height = [ "+10%" ];

        "Mod+V".action = toggle-window-floating;
        "Mod+Shift+V".action = switch-focus-between-floating-and-tiling;
        "Mod+W".action = toggle-column-tabbed-display;

        "Mod+Escape" = {
          action = toggle-keyboard-shortcuts-inhibit;
          allow-inhibiting = false;
        };
        "Mod+Shift+E".action = quit;
        "Ctrl+Alt+Delete".action = quit;
        "Mod+Shift+P".action = power-off-monitors;

        # Screenshots (niri built-in)
        "Print".action.screenshot = { };
        "Shift+Print".action.screenshot-screen = { };
        "Mod+Shift+Print".action.screenshot-window = { };
      };
    };
  };
}
