{ pkgs, ... }:

{
  services.open-webui = {
    enable = true;
    package = pkgs.unstable.open-webui;
    host = "127.0.0.1";
    port = 33801;
  };
}
