{ unstable }:

{
  package = unstable.neovim-unwrapped;
  lineNumberMode = "relNumber";

  globals = {
    mapleader = " ";
    maplocalleader = " ";
    have_nerd_font = true;
  };

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
}
