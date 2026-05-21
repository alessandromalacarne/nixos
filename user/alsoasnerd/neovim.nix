{
  inputs,
  pkgs,
  unstable,
  ...
}:

{
  imports = [
    inputs.nvf.homeManagerModules.default
  ];

  # Note: To allow unfree packages, set at your Home Manager root:
  # nixpkgs.config.allowUnfree = true;

  programs.nvf = {
    enable = true;

    settings = {
      vim = {
        package = unstable.neovim-unwrapped;
        # -------------------------------------------------------
        # Leader
        # -------------------------------------------------------
        globals = {
          mapleader = " ";
          maplocalleader = " ";
          have_nerd_font = true;
        };

        # -------------------------------------------------------
        # Editor Options (from kickstart)
        # -------------------------------------------------------
        lineNumberMode = "relNumber"; # number + relativenumber

        options = {
          swapfile = false;
          mouse = "a";
          showmode = false;
          breakindent = true;
          undofile = true;
          ignorecase = true;
          smartcase = true;
          shiftwidth = 4;
          tabstop = 4;
          expandtab = true;
          signcolumn = "yes";
          updatetime = 250;
          timeoutlen = 300;
          splitright = true;
          splitbelow = true;
          list = true;
          inccommand = "split";
          cursorline = true;
          scrolloff = 10;
        };

        # -------------------------------------------------------
        # Languages (LSP + Treesitter)
        # -------------------------------------------------------
        languages = {
          enableLSP = true;
          enableTreesitter = true;

          rust = {
            enable = true;
            crates.enable = true;
          };

          ts.enable = true; # TypeScript/JavaScript (ts_ls)
          lua.enable = true;
          nix.enable = true;
        };

        # -------------------------------------------------------
        # Built-in nvf Plugin Modules
        # -------------------------------------------------------
        telescope.enable = true;
        binds.whichKey.enable = true;
        visuals.nvim-web-devicons.enable = true;

        git = {
          enable = true;
          gitsigns.enable = true;
        };

        # Statusline via mini
        statusline.lualine.enable = false; # disable lualine if enabled by default

        mini = {
          ai.enable = true;
          surround.enable = true;
          statusline = {
            enable = true;
          };
        };

        # -------------------------------------------------------
        # Native nvf LSP — no Mason, binaries come from extraPackages
        # -------------------------------------------------------
        lsp.enable = true;

        # -------------------------------------------------------
        # Formatting (conform.nvim)
        # -------------------------------------------------------
        formatter = {
          conform-nvim = {
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
        };

        # -------------------------------------------------------
        # Extra plugins not yet natively wrapped by nvf
        # -------------------------------------------------------
        # LSP server binaries — Nix manages these, no Mason needed
        extraPackages = with pkgs; [
          rust-analyzer
          lua-language-server
          stylua
          nodePackages.vscode-langservers-extracted # provides vscode-eslint-language-server
          nodePackages."@tailwindcss/language-server"
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
          # codecompanion-nvim  # uncomment when ready
        ];

        luaConfigRC = {
          # ---- Colorscheme (material deep-ocean) ----
          colorscheme = ''
            require('material').setup()
            vim.cmd.colorscheme('material-deep-ocean')
            vim.cmd.hi('Comment gui=none')
          '';

          # ---- Clipboard (scheduled to avoid startup hit) ----
          clipboard = ''
            vim.schedule(function()
              vim.opt.clipboard = 'unnamedplus'
            end)
          '';

          # ---- listchars (can't be set via vim.options attrset) ----
          listchars = ''
            vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }
          '';

          # ---- Yank highlight autocommand ----
          yankHighlight = ''
            vim.api.nvim_create_autocmd('TextYankPost', {
              desc     = 'Highlight when yanking (copying) text',
              group    = vim.api.nvim_create_augroup('nvf-highlight-yank', { clear = true }),
              callback = function() vim.highlight.on_yank() end,
            })
          '';

          # ---- Diagnostic icons (Nerd Font) ----
          diagnosticIcons = ''
            		  local signs = { ERROR = "", WARN = "", INFO = "", HINT = "" }
            	  local diag_signs = {}
            	  for type, icon in pairs(signs) do
            		  diag_signs[vim.diagnostic.severity[type]] = icon
            			  end
            			  vim.diagnostic.config({ signs = { text = diag_signs }, virtual_text = true })
            			  '';
          # ---- lazydev (Lua API completion) ----
          lazydev = ''
            require('lazydev').setup({
              library = {
                { path = '${"$"}{3rd}/luv/library', words = { 'vim%.uv' } },
              },
            })
          '';
          # ---- LSP servers via Neovim 0.11 native API ----
          # Binaries come from vim.extraPackages (no Mason).
          # languages.lua/ts/nix/rust already call vim.lsp.enable() for their
          # servers; here we only configure servers NOT covered by those modules.
          lspServers = ''
            -- lua_ls: override settings added by the lua language module
            vim.lsp.config('lua_ls', {
              settings = {
                Lua = { completion = { callSnippet = 'Replace' } },
              },
            })

            -- Vue (Volar)
            vim.lsp.config('volar', {
              cmd      = { 'vue-language-server', '--stdio' },
              filetypes = { 'vue' },
              root_markers = { 'package.json', '.git' },
            })
            vim.lsp.enable('volar')

            -- ESLint
            vim.lsp.config('eslint', {
              cmd      = { 'vscode-eslint-language-server', '--stdio' },
              filetypes = {
                'javascript', 'javascriptreact',
                'typescript', 'typescriptreact', 'vue',
              },
              root_markers = {
                '.eslintrc', '.eslintrc.js', '.eslintrc.cjs',
                '.eslintrc.json', 'eslint.config.js', 'eslint.config.mjs',
                'package.json',
              },
              settings = { validate = 'on' },
            })
            vim.lsp.enable('eslint')

            -- Tailwind CSS
            vim.lsp.config('tailwindcss', {
              cmd      = { 'tailwindcss-language-server', '--stdio' },
              filetypes = {
                'css', 'scss', 'sass', 'postcss', 'html',
                'javascript', 'javascriptreact',
                'typescript', 'typescriptreact',
                'svelte', 'vue', 'rust',
              },
              root_markers = {
                'tailwind.config.js', 'tailwind.config.ts',
                'postcss.config.js', 'package.json',
              },
              settings = {
                tailwindCSS = { includeLanguages = { rust = 'html' } },
              },
            })
            vim.lsp.enable('tailwindcss')
          '';

          # ---- LSP attach keymaps ----
          lspAttach = ''
            vim.api.nvim_create_autocmd('LspAttach', {
              group    = vim.api.nvim_create_augroup('nvf-lsp-attach', { clear = true }),
              callback = function(event)
                local map = function(keys, func, desc, mode)
                  mode = mode or 'n'
                  vim.keymap.set(mode, keys, func,
                    { buffer = event.buf, desc = 'LSP: ' .. desc })
                end

                local tb = require('telescope.builtin')
                map('gd',         tb.lsp_definitions,              '[G]oto [D]efinition')
                map('gr',         tb.lsp_references,               '[G]oto [R]eferences')
                map('cd',         vim.diagnostic.open_float,        '[C]ode [D]iagnostics')
                map('gI',         tb.lsp_implementations,           '[G]oto [I]mplementation')
                map('<leader>D',  tb.lsp_type_definitions,          'Type [D]efinition')
                map('<leader>ds', tb.lsp_document_symbols,          '[D]ocument [S]ymbols')
                map('<leader>ws', tb.lsp_dynamic_workspace_symbols, '[W]orkspace [S]ymbols')
                map('<leader>rn', vim.lsp.buf.rename,               '[R]e[n]ame')
                map('<leader>ca', vim.lsp.buf.code_action,          '[C]ode [A]ction', { 'n', 'x' })
                map('gD',         vim.lsp.buf.declaration,          '[G]oto [D]eclaration')

                local client = vim.lsp.get_client_by_id(event.data.client_id)

                if client and client.supports_method(
                  vim.lsp.protocol.Methods.textDocument_documentHighlight) then
                  local hl_group = vim.api.nvim_create_augroup(
                    'nvf-lsp-highlight', { clear = false })
                  vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
                    buffer = event.buf, group = hl_group,
                    callback = vim.lsp.buf.document_highlight,
                  })
                  vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
                    buffer = event.buf, group = hl_group,
                    callback = vim.lsp.buf.clear_references,
                  })
                  vim.api.nvim_create_autocmd('LspDetach', {
                    group    = vim.api.nvim_create_augroup('nvf-lsp-detach', { clear = true }),
                    callback = function(e2)
                      vim.lsp.buf.clear_references()
                      vim.api.nvim_clear_autocmds({
                        group = 'nvf-lsp-highlight', buffer = e2.buf })
                    end,
                  })
                end

                -- eslint: auto-fix on save (replaces Mason's on_attach)
                if client and client.name == 'eslint' then
                  vim.api.nvim_create_autocmd('BufWritePre', {
                    buffer   = event.buf,
                    command  = 'EslintFixAll',
                  })
                end

                if client and client.supports_method(
                  vim.lsp.protocol.Methods.textDocument_inlayHint) then
                  map('<leader>th', function()
                    vim.lsp.inlay_hint.enable(
                      not vim.lsp.inlay_hint.is_enabled({ bufnr = event.buf }))
                  end, '[T]oggle Inlay [H]ints')
                end
              end,
            })
          '';

          # ---- nvim-cmp (completion) ----
          cmp = ''
            local cmp     = require('cmp')
            local luasnip = require('luasnip')
            luasnip.config.setup({})

            cmp.setup({
              enabled = function()
                if vim.bo.filetype == 'oil' then return false end
                return true
              end,
              snippet = {
                expand = function(args) luasnip.lsp_expand(args.body) end,
              },
              completion = { completeopt = 'menu,menuone,noinsert' },
              mapping = cmp.mapping.preset.insert({
                ['<C-n>']     = cmp.mapping.select_next_item(),
                ['<C-p>']     = cmp.mapping.select_prev_item(),
                ['<C-b>']     = cmp.mapping.scroll_docs(-4),
                ['<C-f>']     = cmp.mapping.scroll_docs(4),
                ['<C-y>']     = cmp.mapping.confirm({ select = true }),
                ['<CR>']      = cmp.mapping.confirm({ select = true }),
                ['<C-Space>'] = cmp.mapping.complete({}),
              }),
              sources = {
                { name = 'lazydev', group_index = 0 },
                { name = 'nvim_lsp' },
                { name = 'luasnip' },
                { name = 'path' },
              },
            })
          '';

          # ---- todo-comments ----
          todoComments = ''
            require('todo-comments').setup({ signs = false })
          '';

          # ---- Oil file explorer ----
          oil = ''
            require('oil').setup()
          '';

          # ---- Harpoon v2 ----
          harpoon = ''
            require('harpoon'):setup()
          '';

          # ---- Grug Far ----
          grugFar = ''
            require('grug-far').setup()
          '';

          # ---- which-key group labels (mirrors kickstart spec) ----
          whichKeyGroups = ''
            local wk = require('which-key')
            wk.add({
              { '<leader>c', group = '[C]ode',      mode = { 'n', 'x' } },
              { '<leader>d', group = '[D]ocument' },
              { '<leader>r', group = '[R]ename' },
              { '<leader>s', group = '[S]earch' },
              { '<leader>w', group = '[W]orkspace' },
              { '<leader>t', group = '[T]oggle' },
              { '<leader>h', group = 'Git [H]unk',  mode = { 'n', 'v' } },
              { '<leader>a', group = '[A]I Tools',  mode = { 'n', 'v' } },
              { '<leader>g', group = '[G]it' },
            })
          '';
        };

        # -------------------------------------------------------
        # Keymaps
        # -------------------------------------------------------
        keymaps = [
          # --- Misc ---
          {
            mode = "n";
            key = "<Esc>";
            action = "<cmd>nohlsearch<CR>";
          }
          {
            mode = "n";
            key = "<leader>q";
            action = "<cmd>lua vim.diagnostic.setloclist()<CR>";
            desc = "Open diagnostic [Q]uickfix list";
          }
          {
            mode = "t";
            key = "<Esc><Esc>";
            action = "<C-\\><C-n>";
            desc = "Exit terminal mode";
          }

          # --- Window navigation (arrow keys to avoid colliding with harpoon hjkl) ---
          {
            mode = "n";
            key = "<C-Left>";
            action = "<C-w><C-h>";
            desc = "Move focus to the left window";
          }
          {
            mode = "n";
            key = "<C-Right>";
            action = "<C-w><C-l>";
            desc = "Move focus to the right window";
          }
          {
            mode = "n";
            key = "<C-Down>";
            action = "<C-w><C-j>";
            desc = "Move focus to the lower window";
          }
          {
            mode = "n";
            key = "<C-Up>";
            action = "<C-w><C-k>";
            desc = "Move focus to the upper window";
          }

          # --- Telescope (mirrors kickstart) ---
          {
            mode = "n";
            key = "<leader>sh";
            action = "<cmd>Telescope help_tags<CR>";
            desc = "[S]earch [H]elp";
          }
          {
            mode = "n";
            key = "<leader>sk";
            action = "<cmd>Telescope keymaps<CR>";
            desc = "[S]earch [K]eymaps";
          }
          {
            mode = "n";
            key = "<leader>sf";
            action = "<cmd>Telescope find_files<CR>";
            desc = "[S]earch [F]iles";
          }
          {
            mode = "n";
            key = "<leader>ss";
            action = "<cmd>Telescope builtin<CR>";
            desc = "[S]earch [S]elect Telescope";
          }
          {
            mode = "n";
            key = "<leader>sw";
            action = "<cmd>Telescope grep_string<CR>";
            desc = "[S]earch current [W]ord";
          }
          {
            mode = "n";
            key = "<leader>sg";
            action = "<cmd>Telescope live_grep<CR>";
            desc = "[S]earch by [G]rep";
          }
          {
            mode = "n";
            key = "<leader>sd";
            action = "<cmd>Telescope diagnostics<CR>";
            desc = "[S]earch [D]iagnostics";
          }
          {
            mode = "n";
            key = "<leader>s.";
            action = "<cmd>Telescope oldfiles<CR>";
            desc = "[S]earch Recent Files";
          }
          {
            mode = "n";
            key = "<leader><leader>";
            action = "<cmd>Telescope buffers<CR>";
            desc = "[ ] Find existing buffers";
          }

          # --- Format (conform) ---
          {
            mode = "n";
            key = "<leader>f";
            action = "<cmd>lua require('conform').format({ formatters = { 'injected' }, timeout_ms = 3000 })<CR>";
            desc = "Format Injected Langs";
          }

          # --- File Explorer ---
          {
            mode = "n";
            key = "<leader>pv";
            action = "<cmd>Oil<CR>";
            desc = "Open Oil File Explorer";
          }

          # --- Clipboard & Text Manipulation ---
          {
            mode = "x";
            key = "<leader>P";
            action = "\"_dP";
            desc = "Paste without yanking";
          }
          {
            mode = "n";
            key = "Y";
            action = "y$";
            desc = "Yank to end of line";
          }
          {
            mode = "n";
            key = "J";
            action = "mzJ`z";
            desc = "Join lines keeping cursor position";
          }

          # --- Moving Text in Visual Mode ---
          {
            mode = "v";
            key = "K";
            action = ":m '<-2<CR>gv=gv";
            desc = "Move selected block up";
          }
          {
            mode = "v";
            key = "J";
            action = ":m '>+1<CR>gv=gv";
            desc = "Move selected block down";
          }

          # --- Keeping It Centered ---
          {
            mode = "n";
            key = "<C-d>";
            action = "<C-d>zz";
          }
          {
            mode = "n";
            key = "<C-u>";
            action = "<C-u>zz";
          }
          {
            mode = "n";
            key = "n";
            action = "nzzzv";
          }
          {
            mode = "n";
            key = "N";
            action = "Nzzzv";
          }

          # --- System / External Commands ---
          {
            mode = "n";
            key = "<leader>x";
            action = "<cmd>!chmod +x %<CR>";
            silent = true;
            desc = "Make file executable";
          }
          {
            mode = "n";
            key = "<C-f>";
            action = "<cmd>silent !tmux neww tms<CR>";
            desc = "Open tmux sessionizer";
          }

          # --- Fugitive (Git) ---
          {
            mode = "n";
            key = "<leader>gs";
            action = "<cmd>Git<CR>";
          }
          {
            mode = "n";
            key = "<leader>gp";
            action = "<cmd>Git push<CR>";
          }
          {
            mode = "n";
            key = "<leader>gP";
            action = "<cmd>Git pull<CR>";
          }
          {
            mode = "n";
            key = "<leader>gd";
            action = "<cmd>Git difftool<CR>";
          }
          {
            mode = "n";
            key = "<leader>gl";
            action = "<cmd>Git log<CR>";
          }

          # --- Grug Far (Search & Replace) ---
          {
            mode = "n";
            key = "<leader>sr";
            action = "<cmd>GrugFar<CR>";
            desc = "[S]earch & [R]eplace (GrugFar)";
          }

          # --- LSP ---
          {
            mode = "i";
            key = "<C-s>";
            action = "<cmd>lua vim.lsp.buf.signature_help()<CR>";
            desc = "LSP Signature Help";
          }

          # --- Harpoon v2 ---
          {
            mode = "n";
            key = "<leader>H";
            action = "<cmd>lua require('harpoon'):list():add()<CR>";
          }
          {
            mode = "n";
            key = "<C-h>";
            action = "<cmd>lua require('harpoon'):list():select(1)<CR>";
          }
          {
            mode = "n";
            key = "<C-j>";
            action = "<cmd>lua require('harpoon'):list():select(2)<CR>";
          }
          {
            mode = "n";
            key = "<C-k>";
            action = "<cmd>lua require('harpoon'):list():select(3)<CR>";
          }
          {
            mode = "n";
            key = "<C-l>";
            action = "<cmd>lua require('harpoon'):list():select(4)<CR>";
          }
          {
            mode = "n";
            key = "<C-p>";
            action = "<cmd>lua require('harpoon'):list():prev()<CR>";
          }
          {
            mode = "n";
            key = "<C-n>";
            action = "<cmd>lua require('harpoon'):list():next()<CR>";
          }
          # FIX: rewritten to avoid invalid 'local' in <cmd>lua
          {
            mode = "n";
            key = "<C-o>";
            action = "<cmd>lua require('harpoon').ui:toggle_quick_menu(require('harpoon'):list())<CR>";
          }

          # --- CodeCompanion (uncomment plugin in startPlugins too) ---
          # { mode = "n"; key = "<leader>at"; action = "<cmd>CodeCompanionChat<CR>"; }
          # { mode = "v"; key = "<leader>am"; action = "<cmd>CodeCompanionActions<CR>"; }
          # { mode = "n"; key = "<leader>ac"; action = ":CodeCompanionCmd "; }
        ];
      };
    };
  };
}
