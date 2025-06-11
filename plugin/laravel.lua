-- Laravel.nvim - A comprehensive Laravel development plugin for Neovim
-- Main plugin entry point

if vim.g.loaded_laravel_nvim then
    return
end
vim.g.loaded_laravel_nvim = true

-- Check if we're in a Laravel project
local function is_laravel_project()
    local markers = { 'artisan', 'composer.json', 'app/Http', 'config/app.php' }
    local root = vim.fs.root(0, markers)
    if root then
        -- Additional check for Laravel-specific files
        local artisan_file = root .. '/artisan'
        if vim.fn.filereadable(artisan_file) == 1 then
            return true, root
        end
    end
    return false, nil
end

-- Global state
_G.laravel_nvim = {
    project_root = nil,
    is_laravel_project = false,
    artisan_commands = {},
    blade_snippets = {},
}

-- Initialize Laravel environment
local function initialize_laravel()
    local is_laravel, root = is_laravel_project()
    _G.laravel_nvim.is_laravel_project = is_laravel
    _G.laravel_nvim.project_root = root

    if is_laravel then
        -- Load Laravel-specific configurations
        require('laravel.artisan').setup()
        require('laravel.blade').setup()
        require('laravel.routes').setup()
        require('laravel.models').setup()
        require('laravel.migrations').setup()
        require('laravel.lsp').setup()
    end
end

-- Setup autocommands
local function setup_autocommands()
    local group = vim.api.nvim_create_augroup('LaravelNvim', { clear = true })

    -- Initialize when entering a buffer
    vim.api.nvim_create_autocmd({ 'BufRead', 'BufNewFile' }, {
        group = group,
        callback = function()
            if not _G.laravel_nvim.is_laravel_project then
                initialize_laravel()
            end
        end,
    })

    -- Setup Blade file type detection
    vim.api.nvim_create_autocmd({ 'BufRead', 'BufNewFile' }, {
        group = group,
        pattern = '*.blade.php',
        callback = function()
            vim.bo.filetype = 'blade'
        end,
    })
end

-- Setup user commands
local function setup_commands()
    -- Artisan command
    vim.api.nvim_create_user_command('Artisan', function(opts)
        require('laravel.artisan').run_command(opts.args)
    end, {
        nargs = '*',
        complete = function()
            return require('laravel.artisan').get_completions()
        end,
        desc = 'Run Laravel Artisan commands'
    })

    -- Laravel-specific navigation commands
    vim.api.nvim_create_user_command('LaravelController', function(opts)
        require('laravel.navigate').goto_controller(opts.args)
    end, { nargs = '?', desc = 'Navigate to Laravel controller' })

    vim.api.nvim_create_user_command('LaravelModel', function(opts)
        require('laravel.navigate').goto_model(opts.args)
    end, { nargs = '?', desc = 'Navigate to Laravel model' })

    vim.api.nvim_create_user_command('LaravelView', function(opts)
        require('laravel.navigate').goto_view(opts.args)
    end, { nargs = '?', desc = 'Navigate to Laravel view' })

    vim.api.nvim_create_user_command('LaravelRoute', function()
        require('laravel.routes').show_routes()
    end, { desc = 'Show Laravel routes' })

    vim.api.nvim_create_user_command('LaravelMake', function(opts)
        require('laravel.artisan').make_command(opts.args)
    end, {
        nargs = '*',
        complete = function(arg_lead)
            return require('laravel.artisan').get_make_completions(arg_lead)
        end,
        desc = 'Laravel make commands with fuzzy finder'
    })
end

-- Initialize the plugin
initialize_laravel()
setup_autocommands()
setup_commands()
