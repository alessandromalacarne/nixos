{ pkgs, inputs, ... }:
let
  spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.system};
in
{
  imports = [
    inputs.spicetify-nix.nixosModules.default
  ];

  programs.spicetify = {
    enable = true;

    enabledExtensions = with spicePkgs.extensions; [
      adblockify
      hidePodcasts
      shuffle 
    ];

    enabledCustomApps = with spicePkgs.apps; [
      localFiles
      lyricsPlus
      marketplace
    ];
  };
}
