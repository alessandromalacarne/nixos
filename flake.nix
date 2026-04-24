{
  description = "System Creator Flake";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=main";
    oskars-dotfiles = {
      url = "github:oskardotglobal/.dotfiles/nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    spicetify-nix.url = "github:Gerg-L/spicetify-nix";
    openclaude-flake.url = "github:alessandromalacarne/openclaude-flake";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    jailed-agents.url = "github:andersonjoseph/jailed-agents";
  };

  outputs =
    { self, nixpkgs, ... }@inputs:
    {
      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./configuration.nix
          inputs.nix-flatpak.nixosModules.nix-flatpak
          inputs.home-manager.nixosModules.home-manager
          inputs.sops-nix.nixosModules.sops

          {
            nixpkgs.config.allowUnfree = true;
            nixpkgs.overlays = [
              inputs.oskars-dotfiles.overlays.spotx
              (final: prev: {
                unstable = import inputs.nixpkgs-unstable {
                  system = prev.system;
                  config.allowUnfree = true;
                };
              })
            ];

            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit inputs; };

            home-manager.users = {
              "alsoasnerd" = import /home/alsoasnerd/.config/home-manager/home.nix;
              "dmyna" = import /home/dmyna/.config/home-manager/home.nix;
              # "jiwolfsly" = import /home/jiwolfsly/.config/home-manager/home.nix;
              "dummy" = import /home/dummy/.config/home-manager/home.nix;
            };
          }
        ];
      };
    };
}
