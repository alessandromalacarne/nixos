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
          # The unit runs with a bare PATH, so every binary an app needs is
          # appended explicitly here.
          PATH = "$(PATH):${pkgs.gamescope}/bin:${pkgs.bspwm}/bin:${pkgs.appimage-run}/bin";
        };
        apps = [
          {
            name = "Remoto (bspwm)";
            cmd = "gamescope -W 1920 -H 1080 -f -- bspwm";
          }
          {
            name = "Lichii (emulator)";
            # appimage-run uses bubblewrap, which refuses to start when it
            # inherits the ambient capabilities leaked by the cap-wrapped
            # gamescope/sunshine launchers. setpriv clears them for the child.
            cmd = "${pkgs.gamescope}/bin/gamescope -W 1920 -H 1080 -f -- ${pkgs.util-linux}/bin/setpriv --ambient-caps=-all --inh-caps=-all ${pkgs.appimage-run}/bin/appimage-run /home/alsoasnerd/Downloads/lichii-linux-x86_64.AppImage";
          }
        ];
      };
    };

    input-remapper.enable = true;
  };

  boot.kernelModules = [ "uinput" ];
}
