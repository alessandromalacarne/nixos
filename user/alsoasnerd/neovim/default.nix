{
  inputs,
  pkgs,
  lib,
  unstable,
  ...
}:

let
  inherit (lib) recursiveUpdate;
in
{
  imports = [
    inputs.nvf.homeManagerModules.default
  ];

  # Note: To allow unfree packages, set at your Home Manager root:
  # nixpkgs.config.allowUnfree = true;

  programs.nvf = {
    enable = true;
    settings.vim = recursiveUpdate
      (import ./options.nix { inherit unstable; })
      (recursiveUpdate
        (import ./plugins.nix { inherit pkgs; })
        (recursiveUpdate
          (import ./lsp.nix)
          (recursiveUpdate
            (import ./lua-config.nix)
            (import ./keymaps.nix))));
  };
}
