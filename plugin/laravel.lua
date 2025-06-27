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
        local composer_file = root .. '/composer.json'

        if vim.fn.filereadable(artisan_file) == 1 then
            return true, root
        elseif vim.fn.filereadable(composer_file) == 1 then
            -- Check if composer.json contains Laravel
            local ok, composer_content = pcall(vim.fn.readfile, composer_file)
            if ok then
                local content = table.concat(composer_content, '\n')
                if content:match('"laravel/framework"') or content:match('"laravel/laravel"') then
                    return true, root
                end
            end
        end
    end

    -- Fallback: check current directory
    local cwd = vim.fn.getcwd()
    if vim.fn.filereadable(cwd .. '/artisan') == 1 then
        return true, cwd
    end

    return false, nil
end

-- Global state
_G.laravel_nvim = {
    project_root = nil,
    is_laravel_project = false,
    artisan_commands = {},

}

-- Initialize Laravel environment
local function initialize_laravel()
    local is_laravel, root = is_laravel_project()
    _G.laravel_nvim.is_laravel_project = is_laravel
    _G.laravel_nvim.project_root = root

    -- Always setup basic components (they handle non-Laravel projects gracefully)
    require('laravel.artisan').setup()
    require('laravel.blade').setup()
    require('laravel.routes').setup()
    require('laravel.models').setup()
    require('laravel.migrations').setup()
    require('laravel.keymaps').setup() -- Laravel-specific keymaps
    require('laravel.completions').setup()
    require('laravel.blink_source').setup()

    if is_laravel then
        vim.notify("Laravel.nvim: Laravel project detected at " .. root, vim.log.levels.INFO)
    else
        vim.notify("Laravel.nvim: Loaded (not in Laravel project)", vim.log.levels.INFO)
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

    -- Schema diagram commands
    vim.api.nvim_create_user_command('LaravelSchema', function()
        require('laravel.schema').show_schema_diagram(false)
    end, { desc = 'Show Laravel database schema diagram' })

    vim.api.nvim_create_user_command('LaravelSchemaExport', function()
        require('laravel.schema').show_schema_diagram(true)
    end, { desc = 'Export Laravel database schema diagram to file' })

    -- Architecture diagram commands
    vim.api.nvim_create_user_command('LaravelArchitecture', function()
        require('laravel.architecture').show_architecture_diagram()
    end, { desc = 'Show Laravel application architecture diagram' })

    -- Laravel status command
    vim.api.nvim_create_user_command('LaravelStatus', function()
        local is_laravel = _G.laravel_nvim.is_laravel_project
        local root = _G.laravel_nvim.project_root

        if is_laravel and root then
            vim.notify("Laravel project detected at: " .. root, vim.log.levels.INFO)
        else
            vim.notify("Not in a Laravel project", vim.log.levels.WARN)
        end

        -- Check if artisan is available
        if root then
            local artisan_path = root .. '/artisan'
            if vim.fn.filereadable(artisan_path) == 1 then
                vim.notify("Artisan file found at: " .. artisan_path, vim.log.levels.INFO)
            else
                vim.notify("Artisan file not found at: " .. artisan_path, vim.log.levels.WARN)
            end
        end
    end, { desc = 'Check Laravel.nvim status' })

    -- Completion management commands
    vim.api.nvim_create_user_command('LaravelCompletions', function(opts)
        local completions = require('laravel.completions')
        local func_name = opts.args or 'route'

        local items = completions.get_completions(func_name)
        if #items == 0 then
            vim.notify('No ' .. func_name .. ' completions found', vim.log.levels.WARN)
            return
        end

        vim.notify('Found ' .. #items .. ' ' .. func_name .. ' completions:', vim.log.levels.INFO)
        for i, item in ipairs(items) do
            if i <= 10 then -- Show first 10
                vim.notify('  ' .. item, vim.log.levels.INFO)
            elseif i == 11 then
                vim.notify('  ... and ' .. (#items - 10) .. ' more', vim.log.levels.INFO)
                break
            end
        end
    end, {
        nargs = '?',
        complete = function()
            return { 'route', 'view', 'config', '__', 'trans' }
        end,
        desc = 'Show Laravel completions for a function'
    })

    vim.api.nvim_create_user_command('LaravelClearCache', function()
        require('laravel.completions').clear_cache()
        vim.notify('Laravel completion cache cleared', vim.log.levels.INFO)
    end, { desc = 'Clear Laravel completion cache' })

    -- Test completion system
    vim.api.nvim_create_user_command('LaravelTestCompletions', function()
        local completions = require('laravel.completions')

        vim.notify('Testing Laravel completions...', vim.log.levels.INFO)

        -- Test route completions
        local routes = completions.get_completions('route')
        vim.notify('Routes found: ' .. #routes, vim.log.levels.INFO)

        -- Test view completions
        local views = completions.get_completions('view')
        vim.notify('Views found: ' .. #views, vim.log.levels.INFO)

        -- Test config completions
        local configs = completions.get_completions('config')
        vim.notify('Config keys found: ' .. #configs, vim.log.levels.INFO)

        -- Show first few of each
        if #routes > 0 then
            vim.notify('First route: ' .. routes[1], vim.log.levels.INFO)
        end
        if #views > 0 then
            vim.notify('First view: ' .. views[1], vim.log.levels.INFO)
        end
        if #configs > 0 then
            vim.notify('First config: ' .. configs[1], vim.log.levels.INFO)
        end
    end, { desc = 'Test Laravel completion system' })
end

-- Always setup commands first
setup_commands()

-- Initialize the plugin
initialize_laravel()
setup_autocommands()
