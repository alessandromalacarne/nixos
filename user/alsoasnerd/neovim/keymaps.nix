{
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
}
