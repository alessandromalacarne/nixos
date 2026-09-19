{ config, pkgs, ... }:

{
  services.nginx = {
    enable = true;

    recommendedProxySettings = true;

    virtualHosts."jellyfin.home.arpa" = {
      locations."/" = {
        proxyPass = "http://127.0.0.1:8096";
        proxyWebsockets = true;
      };
    };

    virtualHosts."twenty.home.arpa" = {
      locations."/" = {
        proxyPass = "http://127.0.0.1:3100";
        proxyWebsockets = true;
      };
      extraConfig = "client_max_body_size 50M;";
    };
  };

  networking.firewall.allowedTCPPorts = [
    80
  ];
}
