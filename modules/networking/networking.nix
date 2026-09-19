{ ... }: {
  networking = {
    networkmanager = {
      enable = true;
      dns = "none";
    };

    nameservers = [
      "1.1.1.1"
      "1.0.0.1"
      "8.8.8.8"
      "8.8.4.4"
    ];

    hosts = {
      "100.71.53.50" = [
        "jellyfin.home.arpa"
        "twenty.home.arpa"
      ];
    };

    firewall = {
      enable = true;
      checkReversePath = "loose";
      trustedInterfaces = [ "tailscale0" ];

      allowedUDPPorts = [
        47999
        48010
        48100
        48200
        47998
        48000
      ];
      allowedTCPPorts = [
        22 # SSHD

        3000 # Maya/Katana's Website NextJS (dmyna)

        3050 # Maya Frontend (alsoasnerd)

        3052 # Maya Frontend (jiwolfsly)
        47984
        47989
        48010

        3051 # Maya Frontend debug (dmyna)
        10501 # Maya Rocket debug (dmyna)
        10601 # Maya debug (jiwolfsly)

        10001 # Syncthing (jiwolfsly)

        19000 # Minecraft (jiwolfsly)
      ];
    };
  };
}
