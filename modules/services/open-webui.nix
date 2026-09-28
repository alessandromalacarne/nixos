{ lib, pkgs, ... }:

let
  # Local Speaches instance (modules/services/speech.nix).
  speechApi = "http://127.0.0.1:8000/v1";
in
{
  services.open-webui = {
    enable = true;
    package = pkgs.unstable.open-webui;
    host = "127.0.0.1";
    port = 33801;
    environment = {
      # Speech to text via faster-whisper.
      AUDIO_STT_ENGINE = "openai";
      AUDIO_STT_OPENAI_API_BASE_URL = speechApi;
      AUDIO_STT_OPENAI_API_KEY = "local";
      AUDIO_STT_MODEL = "Systran/faster-whisper-small";

      # Text to speech via Kokoro, Brazilian Portuguese voice.
      AUDIO_TTS_ENGINE = "openai";
      AUDIO_TTS_OPENAI_API_BASE_URL = speechApi;
      AUDIO_TTS_OPENAI_API_KEY = "local";
      AUDIO_TTS_OPENAI_PARAMS = builtins.toJSON { response_format = "mp3"; };
      AUDIO_TTS_MODEL = "speaches-ai/Kokoro-82M-v1.0-ONNX";
      AUDIO_TTS_VOICE = "pf_dora";
      AUDIO_TTS_SPLIT_ON = "punctuation";
    };
  };

  # pydub, which preprocesses recordings before sending them to the STT
  # engine, shells out to ffmpeg and the package does not put it on PATH.
  systemd.services.open-webui.path = [ pkgs.ffmpeg-headless ];

  # The audio.* settings are seeded into webui.db on first start and from then
  # on the database wins over the environment, so clear them and let the values
  # above be re-seeded on every start — the Nix config stays authoritative.
  systemd.services.open-webui.preStart = lib.mkBefore ''
    if [ -f "$DATA_DIR/webui.db" ]; then
      ${lib.getExe' pkgs.sqlite "sqlite3"} "$DATA_DIR/webui.db" \
        "delete from config where key like 'audio.%';" || true
    fi
  '';
}
