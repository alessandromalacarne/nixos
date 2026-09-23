{ config, lib, pkgs, inputs, ... }:

let
  system = pkgs.stdenv.hostPlatform.system;

  aiJail = inputs.ai-jail.packages.${system}.default;
  agents = inputs."llm-agents".packages.${system};

  # ai-jail exposes the host store read-only plus the user and system
  # profiles, so every tool already reachable on PATH works inside the jail
  # and project dependencies never need to be listed anywhere.
  jailConfig = pkgs.writeText "ai-jail.toml" ''
    network = true
    ssh = true

    # Otherwise every run drops an untracked .ai-jail into the project.
    no_save_config = true

    # SHELL is pinned so agents can spawn a shell even when launched from
    # somewhere that does not export it (desktop entries, ssh commands).
    env_pass = [ "TZ", "SHELL=${pkgs.zsh}/bin/zsh" ]

    ro_maps = [
      "${config.home.homeDirectory}/.nix-profile",
      "/run/current-system/sw",
    ]

    rw_maps = [
      "${config.home.homeDirectory}/projects",
      "${config.home.homeDirectory}/.commandcode",
      "${config.home.homeDirectory}/.agents",
      "${config.home.homeDirectory}/.swarmforge",
    ]

    [commands.opencode]
    agent_state = true

    [commands.cursor-agent]
    rw_maps = [
      "${config.home.homeDirectory}/.cursor",
      "${config.home.homeDirectory}/.config/cursor",
      "${config.home.homeDirectory}/.local/share/cursor-agent",
    ]

    [commands.agy]
    rw_maps = [ "${config.home.homeDirectory}/.gemini" ]
  '';

  # Resolved through the store path: a stray ai-jail earlier in PATH (an
  # old ~/.local/bin copy, say) would otherwise silently win and enforce
  # the wrong policy.
  mkJailedAgent =
    name: command:
    pkgs.writeShellApplication {
      inherit name;
      text = ''
        exec ${aiJail}/bin/ai-jail ${command} "$@"
      '';
    };

in
{
  home.packages = [
    aiJail
    agents.opencode
    agents.command-code
    agents.cursor-agent
    agents.antigravity-cli

    (mkJailedAgent "jailed-opencode" "opencode")
    (mkJailedAgent "jailed-cc" "cmd")
    (mkJailedAgent "jailed-cursor" "cursor-agent")
    (mkJailedAgent "jailed-agy" "agy")
  ];

  # ai-jail refuses a symlinked ~/.ai-jail unless the target is owned by the
  # user, which a store path never is, so the generated config is copied into
  # place instead of linked.
  home.activation.aiJailConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD install -m 0644 ${jailConfig} ${config.home.homeDirectory}/.ai-jail
  '';
}
