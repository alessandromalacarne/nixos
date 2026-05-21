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
  };
}
