{ ... }:
{
  services.syncthing = {
    enable = true;
    user = "alsoasnerd";
    openDefaultPorts = true; # Opens 22000/TCP/UDP and 21027/UDP
  };
}
