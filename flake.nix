{
  description = "System Creator Flake";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
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
    llm-agents.url = "github:numtide/llm-agents.nix";
    antigravity-nix = {
      url = "github:jacopone/antigravity-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nvf = {
      url = "github:NotAShelf/nvf";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    noctalia = {
      url = "github:noctalia-dev/noctalia";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    niri-flake.url = "github:sodiboo/niri-flake";
  };

  outputs =
    { self, nixpkgs, ... }@inputs:
    let
      system = "x86_64-linux";
      unstable = import inputs.nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
      };

      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [
          inputs.oskars-dotfiles.overlays.spotx
          inputs.niri-flake.overlays.niri
          (final: prev: {
            unstable = unstable;
          })
        ];
      };
    in
    {
      packages.${system} = {
        rekey-users-secrets = pkgs.writeShellApplication {
          name = "rekey-users-secrets";
          runtimeInputs = [
            pkgs.git
            pkgs.sops
          ];
          text = ''
            set -euo pipefail

            repo_root="$(git rev-parse --show-toplevel)"
            source_file="$repo_root/secrets/users.yaml"
            target_file="$repo_root/secrets/users.yaml.sops"

            if [ ! -f "$source_file" ]; then
              echo "missing plaintext source: $source_file" >&2
              exit 1
            fi

            tmp_file="$(mktemp)"
            trap 'rm -f "$tmp_file"' EXIT

            sops --encrypt \
              --input-type yaml \
              --output-type yaml \
              "$source_file" > "$tmp_file"

            mv "$tmp_file" "$target_file"
            echo "wrote $target_file"
          '';
        };

        rekey-services-secrets = pkgs.writeShellApplication {
          name = "rekey-services-secrets";
          runtimeInputs = [
            pkgs.git
            pkgs.sops
          ];
          text = ''
            set -euo pipefail

            repo_root="$(git rev-parse --show-toplevel)"
            source_file="$repo_root/secrets/services.yaml"
            target_file="$repo_root/secrets/services.yaml.sops"

            if [ ! -f "$source_file" ]; then
              echo "missing plaintext source: $source_file" >&2
              exit 1
            fi

            tmp_file="$(mktemp)"
            trap 'rm -f "$tmp_file"' EXIT

            sops --encrypt \
              --input-type yaml \
              --output-type yaml \
              "$source_file" > "$tmp_file"

            mv "$tmp_file" "$target_file"
            echo "wrote $target_file"
          '';
        };
      };

      apps.${system} = {
        rekey-users-secrets = {
          type = "app";
          program = "${self.packages.${system}.rekey-users-secrets}/bin/rekey-users-secrets";
        };
        rekey-services-secrets = {
          type = "app";
          program = "${self.packages.${system}.rekey-services-secrets}/bin/rekey-services-secrets";
        };
      };

      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        inherit system;

        specialArgs = {
          inherit unstable inputs;
        };

        modules = [
          ./configuration.nix
          inputs.nix-flatpak.nixosModules.nix-flatpak
          inputs.home-manager.nixosModules.home-manager
          inputs.sops-nix.nixosModules.sops
          inputs.niri-flake.nixosModules.niri

          {
            nixpkgs.config.allowUnfree = true;
            nixpkgs.overlays = [
              inputs.oskars-dotfiles.overlays.spotx
              inputs.niri-flake.overlays.niri
              (final: prev: {
                unstable = unstable;
              })
            ];

            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit unstable inputs; };

            # Keep all intended users wired into Home Manager. Evaluation
            # requires read access to each referenced /home path.
            home-manager.users = {
              "alsoasnerd" = import ./user/alsoasnerd/home.nix;
              # "dmyna" = import /home/dmyna/.config/home-manager/home.nix;
              "dummy" = import /home/dummy/.config/home-manager/home.nix;
            };
          }
        ];
      };
    };
}
