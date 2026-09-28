{ config, pkgs, inputs, ... }:

{
  imports = [
    ./programs.nix
    ./bspwm.nix
    ./theme.nix
    ./neovim
    ./noctalia
    ./niri.nix
    ./agents.nix
    ./shell.nix
    ./git.nix
    ./terminals.nix
  ];
  home.username = "alsoasnerd";
  home.homeDirectory = "/home/alsoasnerd";
  nixpkgs.config.allowUnfree = true;

  home.sessionVariables = {
    EDITOR = "nvim";
    PATH = "/home/alsoasnerd/.local/bin:/home/alsoasnerd/.cargo/bin:$PATH";
    LV2_PATH = "/run/current-system/sw/lib/lv2";
    VST3_PATH = "/run/current-system/sw/lib/vst3";
    ZETTELKASTEN_VAULT = "/home/alsoasnerd/Documents/sb";
    OPENCODE_EXPERIMENTAL = "true";
    OPENCODE_ENABLE_EXA = "1";
  };

  programs.home-manager.enable = true;
  home.stateVersion = "24.11";
}
