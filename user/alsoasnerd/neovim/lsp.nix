{
  luaConfigRC = {
    diagnosticIcons = ''
      		  local signs = { ERROR = "", WARN = "", INFO = "", HINT = "" }
      	  local diag_signs = {}
      	  for type, icon in pairs(signs) do
      		  diag_signs[vim.diagnostic.severity[type]] = icon
      			  end
      			  vim.diagnostic.config({ signs = { text = diag_signs }, virtual_text = true })
      			  '';

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
        settings = {
          validate = 'on',
          -- vscode-eslint 3.x runs path.isAbsolute(settings.nodePath) while
          -- resolving settings. Neovim only forwards the keys we set, so an
          -- unset nodePath crashes every textDocument/diagnostic request with
          -- 'The "path" argument must be of type string. Received undefined'.
          nodePath = "",
        },
        before_init = function(_, config)
          -- ESLint scopes config lookup to the workspace folder, a VS Code
          -- concept Neovim does not provide on its own.
          local root_dir = config.root_dir
          if root_dir then
            config.settings = config.settings or {}
            config.settings.workspaceFolder = {
              uri  = vim.uri_from_fname(root_dir),
              name = vim.fn.fnamemodify(root_dir, ':t'),
            }
          end
        end,
        -- Requests the server sends to the client; without handlers Neovim
        -- answers MethodNotFound and the server logs an uncaught exception.
        handlers = {
          ['eslint/openDoc'] = function(_, result)
            if result then vim.ui.open(result.url) end
            return {}
          end,
          ['eslint/confirmESLintExecution'] = function(_, result)
            if not result then return end
            return 4 -- approved
          end,
          ['eslint/probeFailed'] = function()
            vim.notify('[eslint] probe failed', vim.log.levels.WARN)
            return {}
          end,
          ['eslint/noLibrary'] = function()
            vim.notify('[eslint] unable to find the ESLint library', vim.log.levels.WARN)
            return {}
          end,
        },
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
          map('gd',         function()
            tb.lsp_definitions({ file_ignore_patterns = {} })
          end, '[G]oto [D]efinition')
          map('gr',         function()
            tb.lsp_references({ file_ignore_patterns = {} })
          end, '[G]oto [R]eferences')
          map('<leader>flr', function()
            tb.lsp_references({ file_ignore_patterns = {} })
          end, 'LSP: [R]eferences')
          map('cd',         vim.diagnostic.open_float,        '[C]ode [D]iagnostics')
          map('gI',         function()
            tb.lsp_implementations({ file_ignore_patterns = {} })
          end, '[G]oto [I]mplementation')
          map('<leader>D',  function()
            tb.lsp_type_definitions({ file_ignore_patterns = {} })
          end, 'Type [D]efinition')
          map('<leader>ds', tb.lsp_document_symbols,          '[D]ocument [S]ymbols')
          map('<leader>ws', tb.lsp_dynamic_workspace_symbols, '[W]orkspace [S]ymbols')
          map('<leader>rn', vim.lsp.buf.rename,               '[R]e[n]ame')
          map('<leader>ca', vim.lsp.buf.code_action,          '[C]ode [A]ction', { 'n', 'x' })
          map('gD',         vim.lsp.buf.declaration,          '[G]oto [D]eclaration')

          local client = vim.lsp.get_client_by_id(event.data.client_id)

          if client and client:supports_method(
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

          -- eslint: auto-fix on save
          if client and client.name == 'eslint' then
            vim.api.nvim_buf_create_user_command(event.buf, 'EslintFixAll', function()
              client:request_sync('workspace/executeCommand', {
                command   = 'eslint.applyAllFixes',
                arguments = {
                  {
                    uri     = vim.uri_from_bufnr(event.buf),
                    version = vim.lsp.util.buf_versions[event.buf],
                  },
                },
              }, nil, event.buf)
            end, {})

            vim.api.nvim_create_autocmd('BufWritePre', {
              buffer  = event.buf,
              command = 'EslintFixAll',
            })
          end

          if client and client:supports_method(
            vim.lsp.protocol.Methods.textDocument_inlayHint) then
            map('<leader>th', function()
              vim.lsp.inlay_hint.enable(
                not vim.lsp.inlay_hint.is_enabled({ bufnr = event.buf }))
            end, '[T]oggle Inlay [H]ints')
          end
        end,
      })
    '';
  };
}
