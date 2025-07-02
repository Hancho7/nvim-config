-- nerd font
vim.g.have_nerd_font = true

-- Show line numbers
vim.opt.number = true

-- Relative line numbers (helpful for navigation)
vim.opt.relativenumber = true

-- Number of spaces a tab counts for
vim.opt.tabstop = 4

-- Spaces per indent
vim.opt.shiftwidth = 4

-- Convert tabs to spaces
vim.opt.expandtab = true

-- Case-insensitive search
vim.opt.ignorecase = true

-- Case-sensitive if search contains uppercase
vim.opt.smartcase = true

-- Enable true colors (better UI colors)
vim.opt.termguicolors = true

-- Enable persistent undo (undo history after closing files)
vim.opt.undofile = true
vim.opt.undodir = os.getenv("HOME") .. "/.vim/undodir" -- Ensure this directory exists

-- Sync clipboard between OS and Neovim.
--  Schedule the setting after `UiEnter` because it can increase startup-time.
vim.schedule(function()
	vim.opt.clipboard = "unnamedplus"
end)

-- Enable break indent
vim.opt.breakindent = true

-- Case-insensitive searching UNLESS \C or one or more capital letters in the search term
vim.opt.ignorecase = true
vim.opt.smartcase = true

-- Keep signcolumn on by default
vim.opt.signcolumn = "yes"

-- Configure how new splits should be opened
vim.opt.splitright = true
vim.opt.splitbelow = true

-- Preview substitutions live, as you type!
vim.opt.inccommand = "split"

-- Show which line your cursor is on
vim.opt.cursorline = true

-- Minimal number of screen lines to keep above and below the cursor.
vim.opt.scrolloff = 10

-- disable netrw
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
