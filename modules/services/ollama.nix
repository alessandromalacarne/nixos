{ pkgs, ... }:

with pkgs;
{
  users.users.ollama = {
    isSystemUser = true;
    home = "/usr/share/ollama";
    createHome = true;
    group = "ollama";
  };

  users.groups.ollama = { };

  # systemd.services.ollama = {
  #   description = "Ollama Service";
  #   after = [ "network-online.target" ];
  #   wantedBy = [ "multi-user.target" ];
  #   serviceConfig = {
  #     ExecStart = "/run/current-system/sw/bin/ollama serve";
  #     User = "ollama";
  #     Group = "ollama";
  #     Restart = "always";
  #     RestartSec = 3;
  #     Environment = "PATH=/run/current-system/sw/bin/:${pkgs.coreutils}/bin";
  #   };
  # };

  services.ollama = {
    enable = true;
    package = unstable.ollama.override { acceleration = "cuda"; };
    environmentVariables = {
      __NV_PRIME_RENDER_OFFLOAD = "1";
      __NV_PRIME_RENDER_OFFLOAD_DESTINATION = "nvidia";
      __GLX_VENDOR_LIBRARY_NAME = "nvidia";

      LD_LIBRARY_PATH = "/run/opengl-driver/lib:/run/opengl-driver-32/lib";

      OLLAMA_NUM_PARALLEL = "1";
      OLLAMA_HOST = "http://0.0.0.0:11434";
    };
  };

  # --- 3. Permissions ---
  users.groups.video.members = [ "ollama" ];
  users.groups.render.members = [ "ollama" ];

  services.open-webui = {
    enable = true;
    package = unstable.open-webui;
    host = "0.0.0.0";
    port = 33801;
  };
}
