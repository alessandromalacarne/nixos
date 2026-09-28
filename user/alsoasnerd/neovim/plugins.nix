{ pkgs }:

{
  languages = {
    enableTreesitter = true;
    rust = {
      enable = true;
      extensions.crates-nvim.enable = true;
    };
    typescript.enable = true;
    lua.enable = true;
    nix.enable = true;
    markdown.enable = true;
    php = {
      enable = true;
      format.enable = true;
      lsp.servers = [ "intelephense" ];
    };
  };

  telescope.enable = true;
  binds.whichKey.enable = true;
  visuals.nvim-web-devicons.enable = true;
  visuals.indent-blankline.enable = true;

  git = {
    enable = true;
    gitsigns.enable = true;
  };

  statusline.lualine.enable = false;

  mini = {
    ai.enable = true;
    surround.enable = true;
    statusline.enable = true;
  };

  lsp = {
    enable = true;
    trouble.enable = true;
  };

  autopairs.nvim-autopairs.enable = true;

  ui.noice.enable = true;
  notify.nvim-notify.enable = true;

  formatter.conform-nvim = {
    enable = true;
    setupOpts = {
      notify_on_error = false;
      format_on_save = {
        timeout_ms = 500;
        lsp_format = "fallback";
      };
      formatters_by_ft = {
        lua = [ "stylua" ];
        html = [
          "prettierd"
          "prettier"
        ];
      };
    };
  };

  extraPackages = with pkgs; [
    rust-analyzer
    lua-language-server
    stylua
    vscode-langservers-extracted
    tailwindcss-language-server
    vue-language-server
    prettierd
  ];

  startPlugins = with pkgs.vimPlugins; [
    oil-nvim
    harpoon2
    vim-fugitive
    grug-far-nvim
    todo-comments-nvim
    material-nvim
    lazydev-nvim
    fidget-nvim
    nvim-cmp
    cmp-nvim-lsp
    cmp-path
    cmp_luasnip
    luasnip
    conform-nvim
    diffview-nvim
    gitlinker-nvim
    nvim-ufo
    hlchunk-nvim
  ];
}
