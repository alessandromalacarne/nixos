{ lib, ... }: {
  networking = {
    networkmanager.enable = true;

    firewall = {
      enable = true;
      checkReversePath = "loose";
      trustedInterfaces = [ "tailscale0" ];

      allowedUDPPorts = [ 47999 48010 48100 48200 47998 48000 ];
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
