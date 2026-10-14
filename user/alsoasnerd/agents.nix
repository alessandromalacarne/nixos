{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

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
      "${config.home.homeDirectory}/.config",
      "${config.home.homeDirectory}/.local/bin",

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
        exec ${aiJail}/bin/ai-jail --docker ${command} "$@"
      '';
    };

  # ai-jail builds the sandbox PATH from the launcher's environment and
  # prunes entries that are not mounted inside, so the caller's shell
  # cannot be trusted to provide ~/.local/bin. Export it before ai-jail
  # runs; the rw_map above and the activation below keep the directory
  # in place.
  jailedCc = pkgs.writeShellApplication {
    name = "jailed-cc";
    text = ''
      export PATH="${config.home.homeDirectory}/.local/bin:$PATH"
      exec ${aiJail}/bin/ai-jail --env "GIT_SSH_COMMAND=ssh -F /dev/null" --docker cmd "$@"
    '';
  };

  # The CLI writes back to this file when the TUI's settings overlay saves,
  # so it is seeded only when absent instead of linked or overwritten.
  aiUsagebarConfig = pkgs.writeText "ai-usagebar-config.toml" ''
    [ui]
    primary = "commandcode"
  '';

  # `install-hooks` bakes its own store path into every hook command it writes,
  # so the first GC after an ai-memory bump leaves Command Code spawning a
  # deleted binary: hooks exit 127, capture stops silently, and the MCP tools
  # then answer from the default scope because nothing ever publishes the
  # active-project pointer. This wrapper is regenerated on every switch at a
  # path that never changes, so the hook commands outlive the store path.
  aiMemoryHook = pkgs.writeShellApplication {
    name = "ai-memory-hook";
    text = ''
      event="''${1:-}"
      if [ -z "$event" ]; then
        echo "usage: ai-memory-hook <session-start|pre-tool-use|post-tool-use|stop>" >&2
        exit 2
      fi

      exec ${aiMemory}/bin/ai-memory \
        --data-dir ${config.home.homeDirectory}/.local/share/ai-memory \
        hook --event "$event" --agent command-code \
        --server-url "''${AI_MEMORY_HOOK_URL:-http://127.0.0.1:49374}"
    '';
  };

  # Command Code owns ~/.commandcode/settings.json and writes back to it, so
  # the hooks cannot be linked or replaced wholesale: this merges them in,
  # touching only hook entries that call ai-memory and leaving every other key
  # (the CLI's own worktree settings, hooks of other tools) alone.
  commandCodeHookMerge = pkgs.writeText "command-code-hook-merge.py" ''
    import json
    import os
    import sys
    import tempfile

    HOOKS = {
        "SessionStart": "session-start",
        "PreToolUse": "pre-tool-use",
        "PostToolUse": "post-tool-use",
        "Stop": "stop",
    }

    def is_ai_memory(group):
        if not isinstance(group, dict):
            return False
        for hook in group.get("hooks", []):
            if isinstance(hook, dict) and "ai-memory" in str(hook.get("command", "")):
                return True
        return False

    def main():
        path, wrapper = sys.argv[1], sys.argv[2]
        try:
            with open(path, encoding="utf-8") as handle:
                settings = json.load(handle)
        except FileNotFoundError:
            settings = {}
        if not isinstance(settings, dict):
            return 0

        hooks = settings.get("hooks")
        if not isinstance(hooks, dict):
            hooks = {}

        changed = False
        for event, name in HOOKS.items():
            existing = hooks.get(event)
            if not isinstance(existing, list):
                existing = []
            kept = [group for group in existing if not is_ai_memory(group)]
            desired = kept + [
                {"hooks": [{"type": "command", "command": f"{wrapper} {name}"}]}
            ]
            if desired != existing:
                changed = True
                hooks[event] = desired

        if not changed:
            return 0

        settings["hooks"] = hooks
        directory = os.path.dirname(path)
        os.makedirs(directory, exist_ok=True)
        handle, temp = tempfile.mkstemp(dir=directory, prefix=".settings.", suffix=".json")
        with os.fdopen(handle, "w", encoding="utf-8") as out:
            json.dump(settings, out, indent=2)
            out.write("\n")
        os.replace(temp, path)
        return 0

    sys.exit(main())
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
    jailedCc
    (mkJailedAgent "jailed-cursor" "cursor-agent")
    (mkJailedAgent "jailed-agy" "agy")
  ];

  # chezmoi: dot_config/opencode. opencode.json goes through the Home Manager
  # module, which injects $schema and renders the file itself; the two files
  # that have no module option are linked directly from the payload dir.
  # The module gets the llm-agents build as its package rather than null: its
  # warnings option calls lib.getVersion on cfg.package unconditionally, so a
  # null package aborts evaluation of the whole system. Naming the same
  # derivation still keeps pkgs.opencode out of the profile.
  programs.opencode = {
    enable = true;
    package = agents.opencode;

    settings = {
      provider = {
        ollama = {
          name = "Ollama";
          npm = "@ai-sdk/openai-compatible";
          options.baseURL = "http://127.0.0.1:11434/v1";
          models = {
            "minimax-m2.5:cloud" = {
              name = "minimax-m2.5:cloud";
            };
            "minimax-m2.7:cloud" = {
              name = "minimax-m2.7:cloud";
            };
            "glm-5:cloud" = {
              name = "glm-5:cloud";
            };
          };
        };
      };

      plugin = [ "oh-my-opencode-slim" ];

      agent = {
        explore.disable = true;
        general.disable = true;
      };
    };
  };

  xdg.configFile = {
    "opencode/oh-my-opencode-slim.json".source = ./dotfiles/opencode/oh-my-opencode-slim.json;
    "opencode/package.json".source = ./dotfiles/opencode/package.json;
  };

  # ai-jail refuses a symlinked ~/.ai-jail unless the target is owned by the
  # user, which a store path never is, so the generated config is copied into
  # place instead of linked.
  home.activation.aiJailConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD install -m 0644 ${jailConfig} ${config.home.homeDirectory}/.ai-jail
  '';

  # ai-jail skips a map whose source is missing on the host, and PATH
  # pruning then drops the entry inside the sandbox, so ~/.local/bin has
  # to exist even before anything is installed into it.
  home.activation.localBin = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD install -d -m 0755 ${config.home.homeDirectory}/.local/bin
  '';

  home.activation.aiUsagebarConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -e ${config.home.homeDirectory}/.config/ai-usagebar/config.toml ]; then
      $DRY_RUN_CMD install -Dm0644 ${aiUsagebarConfig} ${config.home.homeDirectory}/.config/ai-usagebar/config.toml
    fi
  '';

  home.activation.aiMemoryCommandCodeHooks = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD install -Dm0755 ${aiMemoryHook}/bin/ai-memory-hook ${config.home.homeDirectory}/.local/bin/ai-memory-hook
    $DRY_RUN_CMD ${pkgs.python3}/bin/python3 ${commandCodeHookMerge} \
      ${config.home.homeDirectory}/.commandcode/settings.json \
      ${config.home.homeDirectory}/.local/bin/ai-memory-hook
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
