{ config, pkgs, inputs, ... }:

{
  imports = [ ./programs.nix ./bspwm.nix ./theme.nix ./neovim.nix ];
  home.username = "alsoasnerd";
  home.homeDirectory = "/home/alsoasnerd";
  nixpkgs.config.allowUnfree = true;

  home.sessionVariables = {
    EDITOR = "nvim";
    PATH = "/home/alsoasnerd/.local/bin:$PATH";
    LV2_PATH = "/run/current-system/sw/lib/lv2";
    VST3_PATH = "/run/current-system/sw/lib/vst3";
  };

  programs.home-manager.enable = true;
  home.stateVersion = "24.11";
}
