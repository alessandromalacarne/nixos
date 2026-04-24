{ pkgs, lib, config, inputs, ... }:

with pkgs;

let
  llamaBase = if inputs?llama-cpp then (inputs.llama-cpp.packages.${pkgs.system}.cuda or inputs.llama-cpp.packages.${pkgs.system}.default) else pkgs."llama-cpp";

  # Override the package to force CUDA architectures and MMQ codepath for Turing
  llamaPkg = llamaBase.overrideAttrs (old: let
    oldFlags = old.cmakeFlags or [];
  in {
    cmakeFlags = oldFlags ++ [ "-DCMAKE_CUDA_ARCHITECTURES=61;80" "-DDGGML_CUDA_FORCE_MMQ=ON" ];
  });
in
{
  users.users.llamacpp = {
    isSystemUser = true;
    home = "/usr/share/llamacpp";
    createHome = true;
    group = "llamacpp";
  };

  users.groups.llamacpp = { };

  # Install llama.cpp package so its binaries (llama, llama-cli, llama-server) are
  # available in the system profile and on PATH.
  environment.systemPackages = [ llamaPkg ];

  # systemd.services.llamacpp = {
  #   description = "llama.cpp Service";
  #   after = [ "network-online.target" ];
  #   wantedBy = [ "multi-user.target" ];
  #   serviceConfig = {
  #     ExecStart = "/run/current-system/sw/bin/llama-server --host 0.0.0.0 --port 11434";
  #     User = "llamacpp";
  #     Group = "llamacpp";
  #     Restart = "always";
  #     RestartSec = 3;
  #     Environment = "PATH=/run/current-system/sw/bin/:${pkgs.coreutils}/bin";
  #   };
  # };



  systemd.services.llamacpp = {
    description = "llama.cpp Server";
    after = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${llamaPkg}/bin/llama-server --host 0.0.0.0 --port 11434";
      User = "llamacpp";
      Group = "llamacpp";
      Restart = "always";
      RestartSec = 3;
      Environment = [
        "PATH=/run/current-system/sw/bin/:${pkgs.coreutils}/bin"
        "__NV_PRIME_RENDER_OFFLOAD=1"
        "__NV_PRIME_RENDER_OFFLOAD_DESTINATION=nvidia"
        "__GLX_VENDOR_LIBRARY_NAME=nvidia"
        "LD_LIBRARY_PATH=/run/opengl-driver/lib:/run/opengl-driver-32/lib"
        "LLAMACPP_NUM_PARALLEL=1"
        "LLAMACPP_HOST=http://0.0.0.0:11434"
      ];
    };
  };

  # --- 3. Permissions ---
  users.groups.video.members = [ "llamacpp" ];
  users.groups.render.members = [ "llamacpp" ];
}
