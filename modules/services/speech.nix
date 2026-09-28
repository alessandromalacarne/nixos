{ lib, pkgs, ... }:

let
  port = 8000;
  baseUrl = "http://127.0.0.1:${toString port}";

  sttModel = "Systran/faster-whisper-small";
  ttsModel = "speaches-ai/Kokoro-82M-v1.0-ONNX";

  # The GTX 1650 is only available to the host while configuration.nix keeps
  # gpu-passthrough.nix commented out. Set this to false when you hand the GPU
  # back to the Windows VM, otherwise the container has no device to start with.
  useGpu = true;
in
{
  # Speaches: OpenAI-compatible speech server — faster-whisper for speech to
  # text and Kokoro for text to speech. Published on loopback only, so audio
  # never leaves the machine and no API key or cloud account is involved.
  virtualisation.oci-containers.containers."speaches" = {
    image = "ghcr.io/speaches-ai/speaches:latest-${if useGpu then "cuda" else "cpu"}";
    environment = {
      ENABLE_UI = "false";
      LOG_LEVEL = "info";
      WHISPER__INFERENCE_DEVICE = if useGpu then "cuda" else "cpu";
      WHISPER__COMPUTE_TYPE = if useGpu then "float16" else "int8";
      # Default is 300s, so the model was being unloaded (and reloaded on the
      # next message) every time voice chat went idle for five minutes.
      WHISPER__TTL = "-1";
    };
    volumes = [ "speaches-hf-cache:/home/ubuntu/.cache/huggingface/hub" ];
    ports = [ "127.0.0.1:${toString port}:8000/tcp" ];
    devices = lib.optionals useGpu [ "nvidia.com/gpu=all" ];
    log-driver = "journald";
  };

  systemd.services."podman-speaches".serviceConfig.Restart = lib.mkOverride 90 "always";

  # Pull both models into the cache at boot. Without this the first spoken
  # message stalls for minutes while ~800 MB downloads from Hugging Face.
  systemd.services.speaches-preload-models = {
    description = "Preload Speaches speech models";
    wantedBy = [ "multi-user.target" ];
    after = [ "podman-speaches.service" ];
    requires = [ "podman-speaches.service" ];
    path = [
      pkgs.coreutils
      pkgs.curl
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      Restart = "on-failure";
      RestartSec = "1min";
      TimeoutStartSec = "30min";
    };
    script = ''
      until curl -sf ${baseUrl}/health > /dev/null; do
        sleep 2
      done

      for model in ${sttModel} ${ttsModel}; do
        curl -sf -X POST "${baseUrl}/v1/models/$model" > /dev/null
      done
    '';
  };
}
