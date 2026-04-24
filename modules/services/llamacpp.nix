{ pkgs, lib, config, unstable, ... }:

with pkgs;

let
  llamaPkg = unstable."llama-cpp".override { cudaSupport = true; };
in
{
  users.users.llamacpp = {
    isSystemUser = true;
    home = "/usr/share/llamacpp";
    createHome = true;
    group = "llamacpp";
  };

  users.groups.llamacpp = { };

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
