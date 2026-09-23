{ config, lib, pkgs, inputs, ... }:

let
  system = pkgs.stdenv.hostPlatform.system;

  aiJail = inputs.ai-jail.packages.${system}.default;

  # install-hooks probes for its script bundle at <dir of the binary>/hooks
  # (the release-tarball layout), /usr/local/share and /usr/share; the Nix
  # prefix's own share/ai-memory/hooks is none of those, so the bundle gets
  # the sibling link that the documented commands expect to find.
  aiMemory = (inputs.ai-memory.packages.${system}.default).overrideAttrs (prev: {
    postInstall = prev.postInstall + ''
      ln -s ../share/ai-memory/hooks $out/bin/hooks
    '';
  });

  aiUsagebar = inputs.ai-usagebar.packages.${system}.default;
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

    # ~/.nix-profile needs no map: it resolves inside the sandbox through the
    # bound home and /nix, and bwrap cannot put a mount point on a symlink.
    ro_maps = [ "/run/current-system/sw" ]

    rw_maps = [
      "${config.home.homeDirectory}/projects",
      "${config.home.homeDirectory}/.commandcode",
      "${config.home.homeDirectory}/.agents",
      "${config.home.homeDirectory}/.swarmforge",

      # ai-memory's data dir holds the hook spool and logs that capture
      # inside the jail writes to; read-only, hooks degrade to tmpfs and
      # events vanish when the sandbox exits.
      "${config.home.homeDirectory}/.local/share/ai-memory",
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

  # The CLI writes back to this file when the TUI's settings overlay saves,
  # so it is seeded only when absent instead of linked or overwritten.
  aiUsagebarConfig = pkgs.writeText "ai-usagebar-config.toml" ''
    [ui]
    primary = "commandcode"
  '';

in
{
  home.packages = [
    aiJail
    aiMemory
    aiUsagebar
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

  home.activation.aiUsagebarConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -e ${config.home.homeDirectory}/.config/ai-usagebar/config.toml ]; then
      $DRY_RUN_CMD install -Dm0644 ${aiUsagebarConfig} ${config.home.homeDirectory}/.config/ai-usagebar/config.toml
    fi
  '';

  # `ai-memory init` lays out the data dir and writes the config once, with an
  # auto-generated [auth] token_pepper that must stay out of the store. It
  # never overwrites an existing config, so after the first switch the file
  # belongs to the user (bind address, provider keys, capture policy).
  home.activation.aiMemoryInit = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -e ${config.home.homeDirectory}/.config/ai-memory/config.toml ]; then
      $DRY_RUN_CMD ${aiMemory}/bin/ai-memory \
        --data-dir ${config.home.homeDirectory}/.local/share/ai-memory \
        --config ${config.home.homeDirectory}/.config/ai-memory/config.toml \
        init
    fi
  '';

  # Mirrors the AUR user unit (packaging/systemd/ai-memory-user.service): one
  # data dir owned by the server, the CLI and hooks are thin HTTP clients
  # against loopback. --enable-web adds the read-only wiki browser there too.
  systemd.user.services.ai-memory = {
    Unit = {
      Description = "ai-memory MCP server (user service)";
      Documentation = "https://github.com/akitaonrails/ai-memory";
    };
    Service = {
      Type = "simple";
      ExecStart = "${aiMemory}/bin/ai-memory --data-dir %h/.local/share/ai-memory --config %h/.config/ai-memory/config.toml serve --transport http --enable-web";
      # Optional: bearer token, LLM/embedding provider keys.
      EnvironmentFile = "-%h/.config/ai-memory/env";
      Restart = "on-failure";
      RestartSec = "5s";
      NoNewPrivileges = true;
      PrivateTmp = true;
    };
    Install.WantedBy = [ "default.target" ];
  };
}
