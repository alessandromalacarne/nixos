{ ... }:

{
  xsession.windowManager.bspwm = {
    enable = true;
    extraConfig = ''
      bspc monitor -d 1 2 3 4 5

      bspc config border_width	2
      bspc config window_gap		12

      bspc config split_ratio          0.52
      bspc config borderless_monocle   true
      bspc config gapless_monocle      true
      bspc rule -a "Slinkie Dinkie" state=floating

      pgrep -x sxhkd > /dev/null || sxhkd &
      polybar -c ~/.config/polybar/config.ini &
    '';
  };

  # chezmoi: dot_config/polybar and dot_config/sxhkd, both launched by the
  # extraConfig above. The polybar file is installed as config.ini, which is
  # the path that launcher already uses.
  xdg.configFile = {
    "polybar/config.ini".source = ./dotfiles/polybar.ini;
    "sxhkd/sxhkdrc".source = ./dotfiles/sxhkdrc;
  };
}
