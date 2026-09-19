{ pkgs, ... }:
{
  services = {
    flatpak.enable = true;
    sunshine = {
      enable = true;
      autoStart = true;
      capSysAdmin = true;
      openFirewall = true;

      applications = {
        env = {
          PATH = "$(PATH):${pkgs.gamescope}/bin:${pkgs.bspwm}/bin";
        };
        apps = [
          {
            name = "Remoto (bspwm)";
            command = "gamescope -W 1920 -H 1080 -f -- bspwm";
          }
        ];
      };
    };

    displayManager = {
      defaultSession = "hyprland";
    };

    input-remapper.enable = true;
  };

  boot.kernelModules = [ "uinput" ];
}
