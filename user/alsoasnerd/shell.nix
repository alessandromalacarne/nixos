{
  pkgs,
  ...
}:

let
  # chezmoi: private_dot_local/bin/executable_oyes
  oyes = pkgs.writeShellScriptBin "oyes" ''
    # $1 = Once
    # $2 = To loop
    echo "$1"
    yes "$2"
  '';
in
{
  home.packages = [ oyes ];

  # chezmoi: dot_zsh/git-flow-completion.zsh, sourced from .zshrc
  home.file.".zsh/git-flow-completion.zsh".source = ./dotfiles/git-flow-completion.zsh;

  programs.zsh = {
    enable = true;

    # chezmoi: executable_dot_zshrc (aliases)
    shellAliases = {
      # ls
      ls = "exa --icons";
      l = "ls -lh";
      ll = "ls -lah";
      la = "ls -A";
      lm = "ls -m";
      lr = "ls -R";
      lg = "ls -l --group-directories-first";

      # git
      gcl = "git clone --depth 1";
      gi = "git init";
      ga = "git add";
      gc = "git commit -m";
      gp = "git push origin master";

      # bat
      bat = "bat --style=auto";

      # tmuxp
      ctm = "tmuxp load ~/.config/tmuxp/dev.yaml";

      cpr = "rsync -a --info=progress2";
    };

    # chezmoi: executable_dot_zshrc (everything that is not an alias or an
    # environment variable). `eval "$(starship init zsh)"` is not repeated here
    # because programs.starship.enableZshIntegration emits it.
    initContent = ''
      # set keyboard layout
      setxkbmap -layout us -variant altgr-intl

      # load fzf history
      source <(fzf --zsh)

      # environment socket
      export SSH_AUTH_SOCK="/run/user/$(id -u)/ssh-agent"

      source <(tms --generate zsh)

      source ~/.zsh/git-flow-completion.zsh
    '';
  };

  # chezmoi: dot_config/starship.toml
  programs.starship = {
    enable = true;
    settings = {
      format = "$all\\[$username:$hostname\\] ";
      command_timeout = 3000;

      character.success_symbol = "⬢";

      username = {
        style_user = "white bold";
        style_root = "black bold";
        format = "[$user]($style)";
        disabled = false;
        show_always = true;
      };

      hostname = {
        ssh_only = false;
        format = "[$hostname](bold red)";
        disabled = false;
      };
    };
  };
}
