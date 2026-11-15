# NixOS configuration

My personal NixOS setup, managed as a single flake — [`flake.nix`](flake.nix) pins nixpkgs 26.05 plus `home-manager`, `sops-nix` and friends.

## Layout

- `configuration.nix` — system entry point, wired to the host `nixos`
- `modules/` — system modules (`hardware`, `networking`, `services`, `storage`)
- `user/alsoasnerd/` — home-manager configuration: shell, editors, terminals, theme and packages
- `secrets/` — sops-encrypted secrets; only the `*.sops` files are committed

## Rebuild

```bash
sudo nixos-rebuild switch --flake .#nixos
```

## Secrets

Secrets are managed with [sops-nix](https://github.com/Mic92/sops-nix). Plaintext files are gitignored; the repository only carries the encrypted versions.

## License

[MIT](LICENSE)
