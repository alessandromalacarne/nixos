let
  # Alacritty's `chars` must carry real control characters. Writing the escape
  # as a literal `\u001b` does not survive Home Manager's TOML generation: it
  # reaches the file double-escaped as `\\u001b`, the form alacritty rejects.
  # Nix has no `\uXXXX` escape of its own, so the characters are built from
  # JSON escapes, which the TOML writer then re-escapes correctly as
  # `"\u001b[13;2u"` — byte for byte what the original alacritty.toml had.
  esc = builtins.fromJSON ''"\u001b"'';
  cr = builtins.fromJSON ''"\u000d"'';
in
{
  # chezmoi: dot_config/alacritty/alacritty.toml
  programs.alacritty = {
    enable = true;
    settings = {
      env.TERM = "xterm-256color";

      # Colors (Material Deep Ocean)
      colors = {
        primary = {
          background = "0x0F111A";
          foreground = "0xA6ACCD";
        };
        normal = {
          black = "0x000000";
          blue = "0x6E98EB";
          cyan = "0x71C6E7";
          green = "0xABCF76";
          magenta = "0xB480D6";
          red = "0xDC6068";
          white = "0xEEFFFF";
          yellow = "0xE6B455";
        };
        bright = {
          black = "0x464B5D"; # Disabled color: for zsh-autosuggestions
          blue = "0x82AAFF";
          cyan = "0x89DDFF";
          green = "0xC3E88D";
          magenta = "0xC792EA";
          red = "0xF07178";
          white = "0xEEFFFF";
          yellow = "0xFFCB6B";
        };
        draw_bold_text_with_bright_colors = true;
      };

      font = {
        size = 13.0;
        normal.family = "Cascadia Code NF";
      };

      # Original alacritty.toml, as-is: Shift+Enter sends ESC[13;2u and
      # Shift+Return sends ESC CR.
      keyboard.bindings = [
        {
          key = "Enter";
          mods = "Shift";
          chars = "${esc}[13;2u";
        }
        {
          key = "Return";
          mods = "Shift";
          chars = "${esc}${cr}";
        }
      ];
    };
  };

  # chezmoi: dot_tmux.conf. Settings that Home Manager has first-class options
  # for are expressed as options; everything else is verbatim in extraConfig,
  # which is appended after the generated block.
  programs.tmux = {
    enable = true;
    terminal = "screen-256color";
    baseIndex = 1;
    historyLimit = 100000;
    escapeTime = 0;
    keyMode = "vi";
    mouse = true;
    aggressiveResize = true;
    # Home Manager writes clock-mode-style 12 unless this is set; tmux's own
    # default is 24, which is what the original configuration got.
    clock24 = true;

    # `ctm` in shell.nix loads ~/.config/tmuxp/dev.yaml, so tmuxp is installed
    # here rather than left as a dangling alias.
    tmuxp.enable = true;

    extraConfig = ''
      #set -g prefix C-Space
      # use 256 xterm for pretty colors. This enables same colors from iTerm2 within tmux.
      # This is recommended in neovim :healthcheck
      set -ga terminal-overrides ",xterm-256color:Tc"
      set-option -sa terminal-features ',alacritty:RGB'
      set -s copy-command "xsel -i -b"

      # Path updated from ~/.tmux.conf: tmux.conf is managed through
      # XDG_CONFIG_HOME now, so reloading has to read the new location.
      unbind r
      bind r source-file ~/.config/tmux/tmux.conf \; display-message "Reloaded!"

      # Make a smaller delay so we can perform commands after switching windows
      set -sg repeat-time 600

      # highlight window when it has new activity
      setw -g monitor-activity on
      set -g visual-activity on

      # re-number windows when one is closed
      set -g renumber-windows on

      # neovim integration
      set -g -a terminal-overrides ',*:Ss=\E[%p1%d q:Se=\E[2 q'

      bind C-l send-keys 'C-l' # new clear screen

      # panes
      unbind %
      bind v split-window -h -c "#{pane_current_path}"
      unbind '"'
      bind h split-window -v -c "#{pane_current_path}"

      # windows
      unbind n # DEFAULT KEY: next window
      unbind w # DEFAULT KEY: change current window
      bind w new-window -c "#{pane_current_path}"
      bind n next-window
      bind p previous-window

      # copy mode
      unbind -T copy-mode-vi Space; # default for begin copy
      unbind -T copy-mode-vi Enter; # default for copy selection
      bind -T copy-mode-vi v send -X begin-selection
      bind -T copy-mode-vi y send -X copy-selection-and-cancel "xsel --clipboard"
      bind C-S-c run 'tmux save-buffer - | xsel --clipboard'
      bind C-S-v run 'tmux set-buffer "xsel -b"; tmux paste-buffer'

      # enable pbcopy and pbpaste
      # https://github.com/ChrisJohnsen/tmux-MacOSX-pasteboard/blob/master/README.md
      # bind p paste-buffer
      # set-option -g default-command "reattach-to-user-namespace -l zsh"

      # paste from system clipboard MacOS
      # bind C-v run \"tmux set-buffer \"$(reattach-to-user-namespace pbpaste)\"; tmux paste-buffer"

      ############################
      ## Status Bar
      ############################

      # enable UTF-8 support in status bar
      set -gq status-utf8 on

      # set refresh interval for status bar
      set -g status-interval 30

      # center the status bar
      set -g status-justify centre

      # show session, window, pane in left status bar
      set -g status-left-length 40
      set -g status-left '#[fg=green] #S #[fg=yellow]#I/#[fg=cyan]#P '

      # show hostname, date, tim 100
      set -g status-right '#(battery -t) #[fg=cyan] %d %b %R '

      # update status bar info
      set -g status-interval 60

      ##############
      ### DESIGN ###
      ##############

      # panes
      set -g pane-border-style fg=black
      set -g pane-active-border-style fg=red

      ## Status bar design
      # status line
      set -g status-justify left
      #set -g status-bg default
      set -g status-style fg=blue
      set -g status-interval 2

      # messaging
      set -g message-command-style fg=blue,bg=black

      # window mode
      setw -g mode-style bg=green,fg=black

      # window status
      setw -g window-status-format " #F#I:#W#F "
      setw -g window-status-current-format " #F#I:#W#F "
      setw -g window-status-format "#[fg=magenta]#[bg=black] #I #[bg=cyan]#[fg=white] #W "
      setw -g window-status-current-format "#[bg=brightmagenta]#[fg=white] #I #[fg=white]#[bg=cyan] #W "
      setw -g window-status-current-style bg=black,fg=yellow,dim
      setw -g window-status-style bg=green,fg=black,reverse

      # loud or quiet?
      set -g visual-activity off
      set -g visual-bell off
      set -g visual-silence off
      set-window-option -g monitor-activity off
      set -g bell-action none

      # The modes
      set-window-option -g clock-mode-colour red
      set-window-option -g mode-style fg=red,bg=black,bold

      # The panes
      set -g pane-border-style bg=black,fg=black
      set -g pane-active-border-style fg=blue,bg=black

      # The statusbar
      set -g status-position bottom
      set -g status-style bg=black,fg=yellow,dim
      set -g status-left '''
      set -g status-right '#{?client_prefix,#[fg=white]#[bg=red]#[bold] - PREFIX - ,#[fg=brightwhite]#H}'

      set -g status-right-length 50
      set -g status-left-length 20

      # The window
      set-window-option -g window-status-current-style fg=red,bg=black,bold
      set-window-option -g window-status-current-format ' #I#[fg=brightwhite]:#[fg=brightwhite]#W '

      set-window-option -g window-status-style fg=magenta,bg=black,none
      set-window-option -g window-status-format ' #I#[fg=brightblack]:#[fg=brightblack]#W#[fg=black]#F '

      set-window-option -g window-status-bell-style fg=white,bg=red,bold

      # The messages
      set -g message-style fg=white,bg=red,bold
    '';
  };

  # chezmoi: dot_wezterm.lua. Home Manager writes this to
  # $XDG_CONFIG_HOME/wezterm/wezterm.lua, which wezterm prefers over
  # ~/.wezterm.lua, so the effective config is unchanged.
  programs.wezterm = {
    enable = true;
    settings = {
      window_background_opacity = 0.9;
      color_scheme = "deep";
      # equivalent to wezterm.font("CaskaydiaCove Nerd Font") for a single family
      font = {
        family = "CaskaydiaCove Nerd Font";
      };
      font_size = 13;
      enable_wayland = false;
      hide_tab_bar_if_only_one_tab = true;
    };
  };

  # chezmoi: dot_config/tmuxp/dev.yaml
  xdg.configFile."tmuxp/dev.yaml".source = ./dotfiles/tmuxp-dev.yaml;
}
