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
_G.laravel_nvim = _G.laravel_nvim or {
    project_root = nil,
    is_laravel_project = false,
    artisan_commands = {},
    config = { notifications = true }, -- Default config if not set via setup()
    setup_called = false,              -- Track if setup() has been called
}

-- Initialize Laravel environment
local function initialize_laravel()
    local is_laravel, root = is_laravel_project()
    _G.laravel_nvim.is_laravel_project = is_laravel
    _G.laravel_nvim.project_root = root

    -- Only setup Laravel components if we're in a Laravel project
    if is_laravel then
        require('laravel.artisan').setup()
        require('laravel.blade').setup()
        require('laravel.routes').setup()
        require('laravel.models').setup()
        require('laravel.migrations').setup()
        require('laravel.keymaps').setup() -- Laravel-specific keymaps
        require('laravel.completions').setup()
        require('laravel.blink_source').setup()



        -- Only show notifications if setup() has been called and notifications are enabled
        if _G.laravel_nvim.setup_called and _G.laravel_nvim.config and _G.laravel_nvim.config.notifications then
            vim.notify("Laravel.nvim: Laravel project detected at " .. root, vim.log.levels.INFO)
        end
    else
        -- Only show notifications if setup() has been called and notifications are enabled
        if _G.laravel_nvim.setup_called and _G.laravel_nvim.config and _G.laravel_nvim.config.notifications then
            vim.notify("Laravel.nvim: Not in Laravel project - components not loaded", vim.log.levels.INFO)
        end
    end
end

-- Setup autocommands
local function setup_autocommands()
    local group = vim.api.nvim_create_augroup('LaravelNvim', { clear = true })

    -- Initialize when entering a buffer (only if not already checked)
    vim.api.nvim_create_autocmd({ 'BufRead', 'BufNewFile' }, {
        group = group,
        pattern = { '*.php', '*.blade.php', 'artisan', 'composer.json' },
        callback = function()
            -- Only initialize if we haven't checked for Laravel project yet
            -- and we're in a potentially PHP-related project
            if _G.laravel_nvim.project_root == nil and not _G.laravel_nvim.setup_called then
                local buf_name = vim.api.nvim_buf_get_name(0)
                -- Only trigger for PHP files or Laravel-specific files
                if buf_name:match('%.php$') or buf_name:match('%.blade%.php$') or
                    buf_name:match('artisan$') or buf_name:match('composer%.json$') then
                    initialize_laravel()
                end
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
    -- Artisan command (always available)
    vim.api.nvim_create_user_command('Artisan', function(opts)
        if not (_G.laravel_nvim and _G.laravel_nvim.is_laravel_project) then
            vim.notify('Not in a Laravel project', vim.log.levels.ERROR)
            return
        end
        require('laravel.artisan').run_command(opts.args)
    end, {
        nargs = '*',
        complete = function()
            if not (_G.laravel_nvim and _G.laravel_nvim.is_laravel_project) then
                return {}
            end
            return require('laravel.artisan').get_completions()
        end,
        desc = 'Run Laravel Artisan commands'
    })

    -- Laravel-specific navigation commands (always available)
    vim.api.nvim_create_user_command('LaravelController', function(opts)
        if not (_G.laravel_nvim and _G.laravel_nvim.is_laravel_project) then
            vim.notify('Not in a Laravel project', vim.log.levels.ERROR)
            return
        end
        require('laravel.navigate').goto_controller(opts.args)
    end, { nargs = '?', desc = 'Navigate to Laravel controller' })

    vim.api.nvim_create_user_command('LaravelModel', function(opts)
        if not (_G.laravel_nvim and _G.laravel_nvim.is_laravel_project) then
            vim.notify('Not in a Laravel project', vim.log.levels.ERROR)
            return
        end
        require('laravel.navigate').goto_model(opts.args)
    end, { nargs = '?', desc = 'Navigate to Laravel model' })

    vim.api.nvim_create_user_command('LaravelView', function(opts)
        if not (_G.laravel_nvim and _G.laravel_nvim.is_laravel_project) then
            vim.notify('Not in a Laravel project', vim.log.levels.ERROR)
            return
        end
        require('laravel.navigate').goto_view(opts.args)
    end, { nargs = '?', desc = 'Navigate to Laravel view' })

    vim.api.nvim_create_user_command('LaravelRoute', function()
        if not (_G.laravel_nvim and _G.laravel_nvim.is_laravel_project) then
            vim.notify('Not in a Laravel project', vim.log.levels.ERROR)
            return
        end
        require('laravel.routes').show_routes()
    end, { desc = 'Show Laravel routes' })

    vim.api.nvim_create_user_command('LaravelMake', function(opts)
        if not (_G.laravel_nvim and _G.laravel_nvim.is_laravel_project) then
            vim.notify('Not in a Laravel project', vim.log.levels.ERROR)
            return
        end
        require('laravel.artisan').make_command(opts.args)
    end, {
        nargs = '*',
        complete = function(arg_lead)
            if not (_G.laravel_nvim and _G.laravel_nvim.is_laravel_project) then
                return {}
            end
            return require('laravel.artisan').get_make_completions(arg_lead)
        end,
        desc = 'Laravel make commands with fuzzy finder'
    })

    -- Schema diagram commands (always available)
    vim.api.nvim_create_user_command('LaravelSchema', function()
        if not (_G.laravel_nvim and _G.laravel_nvim.is_laravel_project) then
            vim.notify('Not in a Laravel project', vim.log.levels.ERROR)
            return
        end
        require('laravel.schema').show_schema_diagram(false)
    end, { desc = 'Show Laravel database schema diagram' })

    vim.api.nvim_create_user_command('LaravelSchemaExport', function()
        if not (_G.laravel_nvim and _G.laravel_nvim.is_laravel_project) then
            vim.notify('Not in a Laravel project', vim.log.levels.ERROR)
            return
        end
        require('laravel.schema').show_schema_diagram(true)
    end, { desc = 'Export Laravel database schema diagram to file' })

    -- Architecture diagram commands (always available)
    vim.api.nvim_create_user_command('LaravelArchitecture', function()
        if not (_G.laravel_nvim and _G.laravel_nvim.is_laravel_project) then
            vim.notify('Not in a Laravel project', vim.log.levels.ERROR)
            return
        end
        require('laravel.architecture').show_architecture_diagram()
    end, { desc = 'Show Laravel application architecture diagram' })

    -- Completion management commands (always available)
    vim.api.nvim_create_user_command('LaravelCompletions', function(opts)
        if not (_G.laravel_nvim and _G.laravel_nvim.is_laravel_project) then
            vim.notify('Not in a Laravel project', vim.log.levels.ERROR)
            return
        end
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
            return { 'route', 'view', 'config', '__', 'trans', 'env' }
        end,
        desc = 'Show Laravel completions for a function'
    })

    vim.api.nvim_create_user_command('LaravelClearCache', function()
        if not (_G.laravel_nvim and _G.laravel_nvim.is_laravel_project) then
            vim.notify('Not in a Laravel project', vim.log.levels.ERROR)
            return
        end
        require('laravel.completions').clear_cache()
        vim.notify('Laravel completion cache cleared', vim.log.levels.INFO)
    end, { desc = 'Clear Laravel completion cache' })

    -- Status command (always available for debugging)
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
end



-- Always setup commands first
setup_commands()

-- Setup autocommands (initialization will happen when setup() is called or on first buffer)
setup_autocommands()

-- Only initialize if setup() hasn't been called (for non-lazy loading scenarios)
vim.defer_fn(function()
    if not _G.laravel_nvim.setup_called then
        initialize_laravel()
    end
end, 100) -- Small delay to allow setup() to be called first
