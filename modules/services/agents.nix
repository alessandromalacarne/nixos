{ pkgs, inputs, ... }:

let
  system = pkgs.stdenv.hostPlatform.system;
  llmAgentsPackages = inputs."llm-agents".packages.${system};
  jailedAgents = inputs.jailed-agents.lib.${system};
  mkJailedAgent = jailedAgents.makeJailedAgent;
  mkAgent = args: mkJailedAgent ({ extraPkgs = agentBasePackages; } // args);
  mkAgentWith = builder: args: builder ({ extraPkgs = agentBasePackages; } // args);
  agentBasePackages = with pkgs; [
    bashInteractive
    cargo
    coreutils
    curl
    file
    findutils
    gawk
    git
    pkgsCross.musl64.stdenv.cc
    zlib
    gnumake
    gnugrep
    gnused
    jq
    nixVersions.latest
    nodejs
    openssh
    pkg-config
    ripgrep
    rustc
    tree
    typescript
    unzip
    wget
    which
    yarn
    zip
  ];
in
  {
  environment.systemPackages = with pkgs; [
    (mkAgent {
      name = "jailed-codex";
      pkg = llmAgentsPackages.codex;
      configPaths = [
        "~/.codex"
      ];
    })
    (mkAgentWith jailedAgents.makeJailedOpencode {
      pkg = llmAgentsPackages.opencode;
    })
    (mkAgentWith jailedAgents.makeJailedGeminiCli {
      pkg = llmAgentsPackages.gemini-cli;
    })
    (mkAgentWith jailedAgents.makeJailedOpencode {
      name = "jailed-copilot";
      pkg = llmAgentsPackages.copilot-cli;
      configPaths = [
        "~/.copilot"
      ];
    })
    (mkAgentWith jailedAgents.makeJailedOpencode {
      name = "jailed-cursor";
      pkg = llmAgentsPackages.cursor-agent;
      configPaths = [
        "~/.cursor"
        "~/.config/cursor"
        "~/.local/share/cursor-agent"
      ];
    })

    (mkAgentWith jailedAgents.makeJailedOpencode {
      name = "jailed-kilocode";
        pkg = llmAgentsPackages.kilocode-cli;
      configPaths = [
        "~/.config/kilo"
      ];
    })
    inputs."antigravity-nix".packages.${system}.default
  ];
}

