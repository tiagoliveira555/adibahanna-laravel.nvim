-- Laravel-specific keymaps and utilities
local M = {}

-- Setup Laravel-specific keymaps
-- All Laravel keymaps use <leader>L prefix for organization:
--
-- Global Laravel commands:
--   <leader>Lc - Go to controller
--   <leader>Lm - Go to model
--   <leader>Lv - Go to view
--   <leader>LV - Show related views (context-aware)
--   <leader>Lr - Show routes
--   <leader>La - Run artisan command
--   <leader>Lk - Laravel make command
--   <leader>Ls - Show Laravel status
--
-- Model-specific (in model files):
--   <leader>LR - Show model relationships
--   <leader>LA - Show model attributes
--
-- Migration-specific (in migration files):
--   <leader>Li - Show migration info
--   <leader>LM - Run migration command
--
local function setup_laravel_keymaps()
    -- Setup global Laravel keymaps for PHP files
    vim.api.nvim_create_autocmd('FileType', {
        pattern = 'php',
        callback = function()
            local bufnr = vim.api.nvim_get_current_buf()
            local bufopts = { noremap = true, silent = true, buffer = bufnr }

            -- Laravel-specific navigation with <leader>L prefix
            vim.keymap.set('n', '<leader>Lc', function()
                require('laravel.navigate').goto_controller()
            end, vim.tbl_extend('force', bufopts, { desc = 'Laravel: Go to controller' }))

            vim.keymap.set('n', '<leader>Lm', function()
                require('laravel.navigate').goto_model()
            end, vim.tbl_extend('force', bufopts, { desc = 'Laravel: Go to model' }))

            vim.keymap.set('n', '<leader>Lv', function()
                require('laravel.navigate').goto_view()
            end, vim.tbl_extend('force', bufopts, { desc = 'Laravel: Go to view' }))

            vim.keymap.set('n', '<leader>LV', function()
                require('laravel.navigate').show_related_views()
            end, vim.tbl_extend('force', bufopts, { desc = 'Laravel: Show related views' }))

            vim.keymap.set('n', '<leader>Lr', function()
                require('laravel.routes').show_routes()
            end, vim.tbl_extend('force', bufopts, { desc = 'Laravel: Show routes' }))

            vim.keymap.set('n', '<leader>La', function()
                vim.cmd('Artisan')
            end, vim.tbl_extend('force', bufopts, { desc = 'Laravel: Run artisan command' }))

            vim.keymap.set('n', '<leader>Lk', function()
                require('laravel.artisan').make_command()
            end, vim.tbl_extend('force', bufopts, { desc = 'Laravel: Make command' }))

            vim.keymap.set('n', '<leader>Ls', function()
                vim.cmd('LaravelStatus')
            end, vim.tbl_extend('force', bufopts, { desc = 'Laravel: Show status' }))
        end,
    })

    -- Setup keymaps for Blade files
    vim.api.nvim_create_autocmd('FileType', {
        pattern = 'blade',
        callback = function()
            local bufnr = vim.api.nvim_get_current_buf()
            local bufopts = { noremap = true, silent = true, buffer = bufnr }

            vim.keymap.set('n', '<leader>Lc', function()
                require('laravel.navigate').goto_controller()
            end, vim.tbl_extend('force', bufopts, { desc = 'Laravel: Go to controller' }))

            vim.keymap.set('n', '<leader>Lv', function()
                require('laravel.navigate').goto_view()
            end, vim.tbl_extend('force', bufopts, { desc = 'Laravel: Go to view' }))
        end,
    })
end

-- Main setup function
function M.setup()
    setup_laravel_keymaps()
end

return M
