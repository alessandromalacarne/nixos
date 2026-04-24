{ pkgs, ... }:
{
  services = {
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
  };

  boot.kernelModules = [ "uinput" ];
}
