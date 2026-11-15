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

  services.ollama = {
    enable = true;
    package = unstable.ollama.override { acceleration = "cuda"; };
    # Baixa o modelo automaticamente no boot (ollama-model-loader.service)
    loadModels = [
      "qwen3.5:4b-q4_K_M"
    ];
    syncModels = false;  # true = remove modelos nao declarados
    environmentVariables = {
      # NVIDIA PRIME offload (hybrid graphics: AMD iGPU + NVIDIA dGPU)
      __NV_PRIME_RENDER_OFFLOAD = "1";
      __NV_PRIME_RENDER_OFFLOAD_DESTINATION = "nvidia";
      __GLX_VENDOR_LIBRARY_NAME = "nvidia";
      LD_LIBRARY_PATH = "/run/opengl-driver/lib:/run/opengl-driver-32/lib";

      # Memory / VRAM optimizations (4 GB VRAM on GTX 1650 Ti Mobile)
      OLLAMA_FLASH_ATTENTION = "1";
      OLLAMA_KV_CACHE_TYPE = "q8_0";      # halve KV cache memory
      OLLAMA_CONTEXT_LENGTH = "8192";     # enough for documents
      OLLAMA_NUM_PARALLEL = "1";          # single user
      OLLAMA_MAX_LOADED_MODELS = "1";     # one model at a time

      # Privacy: disable cloud features (no remote inference / web search)
      OLLAMA_NO_CLOUD = "1";

      # Network: accessible from LAN
      OLLAMA_HOST = "http://0.0.0.0:11434";
    };
  };

  # --- Permissions ---
  users.groups.video.members = [ "ollama" ];
  users.groups.render.members = [ "ollama" ];

  services.open-webui = {
    enable = true;
    package = unstable.open-webui;
    host = "0.0.0.0";
    port = 33801;
  };
}
