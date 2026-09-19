{ pkgs, inputs, ... }:

let
  system = pkgs.stdenv.hostPlatform.system;

  llmAgentsPackages = inputs."llm-agents".packages.${system};
  jailedAgents = inputs.jailed-agents.lib.${system};

  agentBasePackages = with pkgs; [
    alacritty
    bashInteractive
    cargo
    coreutils
    curl
    file
    findutils
    gawk
    podman
    git
    zsh
    gcc
    zlib
    gnumake
    gnugrep
    gnused
    jq
    babashka
    nixVersions.latest
    nodejs
    openssh
    pkg-config
    ripgrep
    tree
    typescript
    unzip
    wget
    which
    yarn
    zip
  ];

  mkAgentWith =
    builder: args:
    builder (
      {
        extraPkgs = agentBasePackages;
      }
      // args
    );

in
{
  home.packages = with pkgs; [
    (mkAgentWith jailedAgents.makeJailedOpencode {
      pkg = llmAgentsPackages.opencode;
    })

    (mkAgentWith jailedAgents.makeJailedOpencode {
      name = "jailed-cc";
      pkg = llmAgentsPackages.command-code;

      # jail.nix clears the env, so bash derives SHELL from the fake
      # /etc/passwd (nologin) and Command Code cannot spawn any shell tool.
      env.SHELL = "${pkgs.zsh}/bin/zsh";

      # Scripts with `#!/usr/bin/env ...` shebangs need /usr/bin/env, which
      # the jail does not provide.
      baseJailOptions = jailedAgents.commonJailOptions ++ [
        (jailedAgents.internals.jail.combinators.ro-bind "${pkgs.coreutils}/bin/env" "/usr/bin/env")
        (jailedAgents.internals.jail.combinators.add-path "\"$HOME/.swarmforge/bin\"")
        (jailedAgents.internals.jail.combinators.add-path "\"$HOME/.swarmforge/scripts\"")
      ];

      extraReadonlyDirs = [
        "~/.gitconfig"
        "~/.ssh"
      ];

      extraReadwriteDirs = [
        "~/projects"
        "~/.commandcode"
        "~/.agents"
        "~/.swarmforge"
        "/tmp"
      ];
    })

    (mkAgentWith jailedAgents.makeJailedOpencode {
      name = "jailed-cursor";
      pkg = llmAgentsPackages.cursor-agent;

      extraReadwriteDirs = [
        "~/projects"
        "~/.cursor"
        "~/.config/cursor"
        "~/.local/share/cursor-agent"
      ];
    })

    (mkAgentWith jailedAgents.makeJailedOpencode {
      name = "jailed-agy";
      pkg = llmAgentsPackages.antigravity-cli;

      extraReadwriteDirs = [
        "~/projects"
        "~/.gemini"
      ];
    })
  ];
}
