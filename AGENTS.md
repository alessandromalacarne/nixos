## Build, test, and lint commands

This repo is a NixOS flake config (not an app with unit-test tooling), so validation is mostly Nix evaluation/syntax checks.

```bash
# Single-file "test" (syntax check)
nix-instantiate --parse ./networking.nix >/dev/null

# Whole-repo syntax check for top-level modules
find . -maxdepth 1 -name '*.nix' -print0 | xargs -0 -n1 nix-instantiate --parse >/dev/null

# Flake-provided CI-safe checks (does not require readable /home/* HM paths)
nix run .#nix-check-ci-safe

# Full local check (impure; evaluates host + HM imports)
nix run .#nix-check-local-full

# Encrypt all YAML secret files under ./secrets to matching .sops outputs (fast local script)
./scripts/sops-encrypt-yaml-secrets.sh

# Same encryption flow via flake app
nix run .#sops-encrypt-yaml-secrets

# Inspect flake outputs
nix flake show --no-write-lock-file path:$(pwd)

# Format Nix files via flake formatter output
nix fmt

# Full flake evaluation checks (requires impure eval for /home imports)
nix flake check --impure --no-write-lock-file path:$(pwd)

# Apply system configuration on host
sudo nixos-rebuild switch --impure --flake .#nixos
```

Notes for Copilot sessions:
- `nix flake check` in pure mode fails because `flake.nix` imports Home Manager files from absolute `/home/...` paths.
- Even with `--impure`, evaluation can fail if the current user cannot read all imported `/home/*/.config/home-manager/home.nix` paths.
- Home Manager privacy constraint: keep per-user configs under `/home/<user>/.config/home-manager`.
- Check helper apps isolate `HOME`/`XDG_*`/`NIX_USER_PROFILE_DIR` to avoid profile permission failures in constrained environments.

## High-level architecture

- **Entry point:** `flake.nix` defines one host: `nixosConfigurations.nixos`.
- **Composition model:** `configuration.nix` is the main orchestrator and imports domain modules:
  - `nvidia.nix`, `ollama.nix`, `audio.nix`, `virtualization.nix`, `bluetooth.nix`, `filesys.nix`, `networking.nix`, `servers.nix`, `spicetify.nix`, plus `hardware-configuration.nix`.
- **Package sources:** stable `nixpkgs` plus an `unstable` overlay; modules consume unstable packages via `unstable.<pkg>` (e.g. Ollama/Open WebUI).
- **Home Manager integration:** `flake.nix` wires Home Manager users via absolute imports under `/home/.../.config/home-manager/home.nix` and passes `inputs` through `home-manager.extraSpecialArgs`.
- **Service surface area:** system services and exposed ports are spread across dedicated modules (`networking.nix`, `servers.nix`, `ollama.nix`, plus service sections in `configuration.nix`).

## Key conventions in this codebase

- Keep the config **module-per-domain** at repository root (`<domain>.nix`) and wire new modules through `configuration.nix` `imports`.
- Prefer **option ownership in its domain module** (network/firewall in `networking.nix`, virtualization in `virtualization.nix`, GPU in `nvidia.nix`, etc.) instead of centralizing all changes in `configuration.nix`.
- Use stable `pkgs` by default and opt into `unstable.<pkg>` only where needed.
- Port and service entries often include inline comments naming the owner/use case; preserve this style when editing firewall/service blocks.
- Treat `hardware-configuration.nix` as generated input (do not hand-edit unless intentionally overriding generated behavior elsewhere).
- Use **semantic commit messages** and keep commits **atomic** (one concern per commit).
