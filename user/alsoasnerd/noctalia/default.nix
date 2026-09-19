{ inputs, ... }:

{
  imports = [
    inputs.noctalia.homeModules.default
  ];
  programs.noctalia = {
    enable = true;
    settings = {
      backdrop = {
        enable = true;
      };

      wallpaper = {
        enabled = true;
        directory = "/home/alsoasnerd/Pictures/Wallpapers";
        default.path = "/home/alsoasnerd/Pictures/Wallpapers/wallhaven-dg5kkm_1920x1080.png";
      };

      bar.default = {
        center = [
          "clock"
          "cat"
        ];
        margin_ends = 120;
      };

      desktop_widgets = {
        schema_version = 2;
        widget_order = [ ];
        grid = {
          cell_size = 16;
          major_interval = 4;
          visible = true;
        };
        widget = { };
      };

      dock = {
        auto_hide = true;
        enabled = true;
        icon_size = 38;
        reserve_space = false;
      };

      location = {
        address = "Juiz de Fora, Minas Gerais";
      };

      lockscreen_widgets = {
        enabled = false;
        schema_version = 2;
        widget_order = [ "lockscreen-login-box@eDP-1" ];
        grid = {
          cell_size = 16;
          major_interval = 4;
          visible = true;
        };
        widget."lockscreen-login-box@eDP-1" = {
          box_height = 0.0;
          box_width = 0.0;
          cx = 960.0;
          cy = 957.0;
          output = "eDP-1";
          rotation = 0.0;
          type = "login_box";
          settings = {
            background_color = "surface_variant";
            background_opacity = 0.88;
            background_radius = 12.0;
            input_opacity = 1.0;
            input_radius = 6.0;
            show_login_button = true;
          };
        };
      };

      plugins = {
        enabled = [ "noctalia/bongocat" ];
      };

      shell = {
        corner_radius_scale = 1.3000000193715096;
        niri_overview_type_to_launch_enabled = true;
        screen_time_enabled = true;
        panel = {
          control_center_placement = "floating";
          launcher_session_search = true;
          transparency_mode = "glass";
        };
      };

      theme = {
        builtin = "Noctalia";
        community_palette = "Noctalia legacy";
        mode = "dark";
        source = "builtin";
        wallpaper_scheme = "m3-content";
      };

      widget.cat = {
        type = "noctalia/bongocat:cat";
      };
    };
  };
}
