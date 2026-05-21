{
  inputs,
  pkgs,
  unstable,
  ...
}:

{
  imports = [
    inputs.nvf.homeManagerModules.default
  ];

  # Note: To allow unfree packages, set at your Home Manager root:
  # nixpkgs.config.allowUnfree = true;

  programs.nvf = {
    enable = true;
    settings.vim = {
      imports = [
        (import ./options.nix { inherit unstable; })
        (import ./plugins.nix { inherit pkgs; })
        (import ./lsp.nix)
        (import ./lua-config.nix)
        (import ./keymaps.nix)
      ];
    };
  };
}
