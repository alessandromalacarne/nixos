{
  lib,
  config,
  ...
}:

let
  user = "alsoasnerd";
  baseDir = "/home/${user}/.config/pihole";
  tailscaleIp = "100.71.53.50";
  localHosts = [
    "bookorbit.home.arpa"
    "jellyfin.home.arpa"
    "openwebui.home.arpa"
    "twenty.home.arpa"
  ];

in
{
  sops.secrets."services/pihole/web_password" = {
    sopsFile = ../../secrets/services.yaml.sops;
  };

  virtualisation.oci-containers.containers."pihole" = {
    image = "pihole/pihole:latest";
    environment = {
      TZ = "America/Sao_Paulo";
      FTLCONF_dns_upstreams = "1.0.0.1;8.8.8.8;8.8.4.4";
      FTLCONF_dns_listeningMode = "all";
      FTLCONF_webserver_allowall_origins = "true";
      FTLCONF_dns_hosts = lib.concatMapStringsSep ";" (host: "${tailscaleIp} ${host}") localHosts;
    };
    environmentFiles = [
      config.sops.secrets."services/pihole/web_password".path
    ];
    volumes = [
      "${baseDir}/config:/etc/pihole:rw"
    ];
    ports = [
      "${tailscaleIp}:53:53/tcp"
      "${tailscaleIp}:53:53/udp"
      "127.0.0.1:8081:80/tcp"
      "${tailscaleIp}:8081:80/tcp"
    ];
    log-driver = "journald";
  };

  systemd.services."podman-pihole" = {
    preStart = ''
      mkdir -p ${baseDir}/config
    '';
    serviceConfig.Restart = lib.mkOverride 90 "always";
  };

  systemd.tmpfiles.rules = [
    "D ${baseDir}/config 0755 ${user} users - -"
  ];
}
