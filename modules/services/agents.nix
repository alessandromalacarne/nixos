{ pkgs, inputs }:

let
  system = pkgs.stdenv.hostPlatform.system;
  llmAgentsPackages = inputs."llm-agents".packages.${system};
in
pkgs.mkShell {
  packages = [
    llmAgentsPackages.codex
    llmAgentsPackages.opencode
    llmAgentsPackages.gemini-cli
    llmAgentsPackages.qwen-code
    llmAgentsPackages.copilot-cli
    llmAgentsPackages.cursor-agent
    inputs."antigravity-nix".packages.${system}.default
  ];
}
