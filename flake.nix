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
    let
      system = "x86_64-linux";
      overlays = [
        inputs.oskars-dotfiles.overlays.spotx
        (final: prev: {
          unstable = import inputs.nixpkgs-unstable {
            system = prev.system;
            config.allowUnfree = true;
          };
        })
      ];
      pkgs = import nixpkgs {
        inherit system overlays;
        config.allowUnfree = true;
      };

      # Privacy constraint: keep Home Manager modules in each user's home directory.
      homeManagerUserModules = {
        "alsoasnerd" = /home/alsoasnerd/.config/home-manager/home.nix;
        "dmyna" = /home/dmyna/.config/home-manager/home.nix;
        # "jiwolfsly" = /home/jiwolfsly/.config/home-manager/home.nix;
        "dummy" = /home/dummy/.config/home-manager/home.nix;
      };

      ciSafeCheck = pkgs.writeShellApplication {
        name = "nix-check-ci-safe";
        runtimeInputs = with pkgs; [
          findutils
          nix
        ];
        text = ''
          set -euo pipefail

          if [ ! -f flake.nix ]; then
            echo "Run this command from the repository root (flake.nix not found)." >&2
            exit 1
          fi

          find . -maxdepth 1 -name '*.nix' -print0 | xargs -0 -n1 nix-instantiate --parse >/dev/null
          nix flake show --no-write-lock-file path:"$(pwd)" >/dev/null
        '';
      };

      localFullCheck = pkgs.writeShellApplication {
        name = "nix-check-local-full";
        runtimeInputs = [ pkgs.nix ];
        text = ''
          set -euo pipefail

          if [ ! -f flake.nix ]; then
            echo "Run this command from the repository root (flake.nix not found)." >&2
            exit 1
          fi

          nix flake check --impure --no-write-lock-file path:"$(pwd)"
        '';
      };
    in
    {
      formatter.${system} = pkgs.nixfmt-rfc-style;

      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          git
          nh
          nix
          nixfmt-rfc-style
        ];
      };

      checks.${system}.nix-syntax = pkgs.runCommand "nix-syntax-check" { } ''
        ${pkgs.findutils}/bin/find ${self} -maxdepth 1 -name '*.nix' -print0 \
          | ${pkgs.findutils}/bin/xargs -0 -n1 ${pkgs.nix}/bin/nix-instantiate --parse >/dev/null
        touch "$out"
      '';

      apps.${system} = {
        nix-check-ci-safe = {
          type = "app";
          program = "${ciSafeCheck}/bin/nix-check-ci-safe";
          meta.description = "CI-safe syntax and flake output checks";
        };

        nix-check-local-full = {
          type = "app";
          program = "${localFullCheck}/bin/nix-check-local-full";
          meta.description = "Local full flake check with impure evaluation";
        };
      };

      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [
          ./configuration.nix
          inputs.nix-flatpak.nixosModules.nix-flatpak
          inputs.home-manager.nixosModules.home-manager
          inputs.sops-nix.nixosModules.sops

          {
            nixpkgs.config.allowUnfree = true;
            nixpkgs.overlays = overlays;

            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit inputs; };
            home-manager.users = builtins.mapAttrs (_: modulePath: import modulePath) homeManagerUserModules;
          }
        ];
      };
    };
}
