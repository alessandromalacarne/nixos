{
  pkgs,
  lib,
  config,
  ...
}:

let
  user = "alsoasnerd";
  baseDir = "/home/${user}/Documents/Library/twenty";

in
{
  sops.secrets."services/twenty/pg_password" = {
    sopsFile = ../../secrets/services.yaml.sops;
  };
  sops.secrets."services/twenty/pg_url" = {
    sopsFile = ../../secrets/services.yaml.sops;
  };
  sops.secrets."services/twenty/app_secret" = {
    sopsFile = ../../secrets/services.yaml.sops;
  };
  sops.secrets."services/twenty/encryption_key" = {
    sopsFile = ../../secrets/services.yaml.sops;
  };

  virtualisation.oci-containers.containers."twenty-db" = {
    image = "postgres:16";
    environment = {
      POSTGRES_DB = "default";
      POSTGRES_USER = "postgres";
    };
    environmentFiles = [
      config.sops.secrets."services/twenty/pg_password".path
    ];
    volumes = [
      "${baseDir}/postgres:/var/lib/postgresql/data:rw"
    ];
    log-driver = "journald";
    extraOptions = [
      "--health-cmd=pg_isready -U postgres -h localhost -d default"
      "--health-interval=5s"
      "--health-retries=10"
      "--health-timeout=5s"
      "--network-alias=twenty-db"
      "--network=twenty_default"
    ];
  };

  virtualisation.oci-containers.containers."twenty-redis" = {
    image = "redis:8-alpine";
    cmd = [
      "--maxmemory-policy"
      "noeviction"
    ];
    log-driver = "journald";
    extraOptions = [
      "--health-cmd=redis-cli ping"
      "--health-interval=5s"
      "--health-retries=10"
      "--health-timeout=5s"
      "--network-alias=twenty-redis"
      "--network=twenty_default"
    ];
  };

  virtualisation.oci-containers.containers."twenty-server" = {
    image = "twentycrm/twenty:latest";
    environment = {
      NODE_PORT = "3000";
      SERVER_URL = "http://twenty.home.arpa";
      REDIS_URL = "redis://twenty-redis:6379";
    };
    environmentFiles = [
      config.sops.secrets."services/twenty/pg_url".path
      config.sops.secrets."services/twenty/app_secret".path
      config.sops.secrets."services/twenty/encryption_key".path
    ];
    volumes = [
      "${baseDir}/local-storage:/app/packages/twenty-server/.local-storage:rw"
    ];
    ports = [
      "127.0.0.1:3100:3000/tcp"
    ];
    dependsOn = [
      "twenty-db"
      "twenty-redis"
    ];
    log-driver = "journald";
    extraOptions = [
      "--health-cmd=curl --fail http://localhost:3000/healthz"
      "--health-interval=5s"
      "--health-retries=20"
      "--health-timeout=5s"
      "--network-alias=twenty-server"
      "--network=twenty_default"
    ];
  };

  virtualisation.oci-containers.containers."twenty-worker" = {
    image = "twentycrm/twenty:latest";
    cmd = [
      "yarn"
      "worker:prod"
    ];
    environment = {
      REDIS_URL = "redis://twenty-redis:6379";
      DISABLE_DB_MIGRATIONS = "true";
      DISABLE_CRON_JOBS_REGISTRATION = "true";
    };
    environmentFiles = [
      config.sops.secrets."services/twenty/pg_url".path
      config.sops.secrets."services/twenty/app_secret".path
      config.sops.secrets."services/twenty/encryption_key".path
    ];
    volumes = [
      "${baseDir}/local-storage:/app/packages/twenty-server/.local-storage:rw"
    ];
    dependsOn = [
      "twenty-server"
    ];
    log-driver = "journald";
    extraOptions = [
      "--network-alias=twenty-worker"
      "--network=twenty_default"
    ];
  };

  systemd.services."podman-twenty-db" = {
    preStart = ''
      mkdir -p ${baseDir}/postgres
      chown -R 999:999 ${baseDir}/postgres
    '';
    serviceConfig.Restart = lib.mkOverride 90 "always";
    after = [ "podman-network-twenty_default.service" ];
    requires = [ "podman-network-twenty_default.service" ];
    partOf = [ "podman-compose-twenty-root.target" ];
    wantedBy = [ "podman-compose-twenty-root.target" ];
  };

  systemd.services."podman-twenty-redis" = {
    serviceConfig.Restart = lib.mkOverride 90 "always";
    after = [ "podman-network-twenty_default.service" ];
    requires = [ "podman-network-twenty_default.service" ];
    partOf = [ "podman-compose-twenty-root.target" ];
    wantedBy = [ "podman-compose-twenty-root.target" ];
  };

  systemd.services."podman-twenty-server" = {
    preStart = ''
      mkdir -p ${baseDir}/local-storage
      chown -R 1000:1000 ${baseDir}/local-storage
    '';
    serviceConfig.Restart = lib.mkOverride 90 "always";
    after = [ "podman-network-twenty_default.service" ];
    requires = [ "podman-network-twenty_default.service" ];
    partOf = [ "podman-compose-twenty-root.target" ];
    wantedBy = [ "podman-compose-twenty-root.target" ];
  };

  systemd.services."podman-twenty-worker" = {
    serviceConfig.Restart = lib.mkOverride 90 "always";
    after = [ "podman-network-twenty_default.service" ];
    requires = [ "podman-network-twenty_default.service" ];
    partOf = [ "podman-compose-twenty-root.target" ];
    wantedBy = [ "podman-compose-twenty-root.target" ];
  };

  systemd.services."podman-network-twenty_default" = {
    path = [ pkgs.podman ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStop = "podman network rm -f twenty_default";
    };
    script = ''
      podman network inspect twenty_default || podman network create twenty_default
    '';
    partOf = [ "podman-compose-twenty-root.target" ];
    wantedBy = [ "podman-compose-twenty-root.target" ];
  };

  systemd.targets."podman-compose-twenty-root" = {
    unitConfig.Description = "Root target generated by compose2nix.";
    wantedBy = [ "multi-user.target" ];
  };

  systemd.tmpfiles.rules = [
    "D ${baseDir}/postgres 0700 999 999 - -"
    "D ${baseDir}/local-storage 0755 1000 1000 - -"
  ];
}
