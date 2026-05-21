{
  luaConfigRC = {
    colorscheme = ''
      require('material').setup()
      vim.cmd.colorscheme('material-deep-ocean')
      vim.cmd.hi('Comment gui=none')
    '';

    clipboard = ''
      vim.schedule(function()
        vim.opt.clipboard = 'unnamedplus'
      end)
    '';

    listchars = ''
      vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }
    '';

    yankHighlight = ''
      vim.api.nvim_create_autocmd('TextYankPost', {
        desc     = 'Highlight when yanking (copying) text',
        group    = vim.api.nvim_create_augroup('nvf-highlight-yank', { clear = true }),
        callback = function() vim.highlight.on_yank() end,
      })
    '';

    lazydev = ''
      require('lazydev').setup({
        library = {
          { path = '${"$"}{3rd}/luv/library', words = { 'vim%.uv' } },
        },
      })
    '';

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

    todoComments = ''
      require('todo-comments').setup({ signs = false })
    '';

    oil = ''
      require('oil').setup()
    '';

    harpoon = ''
      require('harpoon'):setup()
    '';

    grugFar = ''
      require('grug-far').setup()
    '';

    ufo = ''
      vim.opt.foldenable = true
      vim.opt.foldlevel = 99
      vim.opt.foldlevelstart = 99
      vim.opt.foldcolumn = '1'
      vim.opt.fillchars = { foldopen = ' ', foldclose = ' ', fold = ' ', foldsep = ' ' }
      vim.keymap.set('n', 'zR', function() require('ufo').openAllFolds() end)
      vim.keymap.set('n', 'zM', function() require('ufo').closeAllFolds() end)
      vim.keymap.set('n', 'zr', function() require('ufo').openFoldsExceptKinds() end)
      vim.keymap.set('n', 'zm', function() require('ufo').closeFoldsWith() end)
      vim.keymap.set('n', 'K', function()
        local winid = require('ufo').peekFoldedLinesUnderCursor()
        if not winid then vim.lsp.buf.hover() end
      end, { desc = 'Peek folded lines or LSP hover' })
      require('ufo').setup({
        provider_selector = function(_, filetype, buftype)
          return { 'treesitter', 'indent' }
        end,
      })
    '';

    hlchunk = ''
      require('hlchunk').setup({
        chunk = {
          enable = true,
          style = { underline = true },
        },
        indent = {
          enable = true,
          chars = { '▏' },
        },
        blank = {
          enable = false,
        },
        line_num = {
          enable = true,
          style = '#806d9c',
        },
      })
    '';

    gitlinker = ''
      require('gitlinker').setup({
        opts = {
          remote = nil,
          add_current_line_on_normal_mode = true,
          action_callback = require('gitlinker.actions').copy_to_clipboard,
          print_url = true,
        },
      })
    '';

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
}
