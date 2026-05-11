{ ... }:
{
  services.syncthing = {
    enable = true;
    user = "alsoasnerd";
    configDir = "/home/alsoasnerd/.config/syncthing";
    openDefaultPorts = true; # Opens 22000/TCP/UDP and 21027/UDP
    guiAddress = "0.0.0.0:8384";
  };
}
