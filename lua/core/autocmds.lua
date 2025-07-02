-- Create a group for autocommands (avoids duplicates on reload)
local autocmd_group = vim.api.nvim_create_augroup('MyCustomCmds', { clear = true })

-- Trim trailing whitespace on save
vim.api.nvim_create_autocmd('BufWritePre', {
    group = autocmd_group,
    pattern = '*',
    command = '%s/\\s\\+$//e',
})

-- Highlight yanked text briefly
vim.api.nvim_create_autocmd('TextYankPost', {
    group = autocmd_group,
    pattern = '*',
    callback = function()
        vim.highlight.on_yank({ timeout = 200 })
    end,
})
