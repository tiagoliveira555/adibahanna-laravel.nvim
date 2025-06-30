-- Laravel.nvim - Main module
local M = {}

-- Default configuration
local default_config = {
    notifications = true,         -- Enable/disable Laravel.nvim notifications
    debug = false,                -- Enable/disable debug error notifications
    keymaps = true,               -- Enable/disable Laravel.nvim keymaps
    sail = {
        enabled = true,           -- Enable/disable Laravel Sail integration
        auto_detect = true,       -- Auto-detect Sail usage in project
        url = 'http://localhost', -- URL to open when using SailOpen command
    },
}

-- Global state
_G.laravel_nvim = _G.laravel_nvim or {}

-- Find Laravel project root
local function find_laravel_project_root()
    local current_dir = vim.fn.getcwd()
    local function check_laravel_markers(dir)
        local markers = { 'artisan', 'composer.json', 'app/Http/Kernel.php' }
        for _, marker in ipairs(markers) do
            if vim.fn.filereadable(dir .. '/' .. marker) == 1 then
                return true
            end
        end
        return false
    end

    -- Check current directory and parents
    local dir = current_dir
    while dir ~= '/' do
        if check_laravel_markers(dir) then
            return dir
        end
        dir = vim.fn.fnamemodify(dir, ':h')
    end

    return nil
end

-- Setup function
function M.setup(config)
    config = vim.tbl_deep_extend('force', default_config, config or {})

    -- Store configuration in global state
    _G.laravel_nvim.config = config
    _G.laravel_nvim.setup_called = true

    -- Set global debug flag for completion error notifications
    vim.g.laravel_nvim_debug = config.debug

    -- Find and set Laravel project root
    local project_root = find_laravel_project_root()
    if project_root then
        _G.laravel_nvim.project_root = project_root
        _G.laravel_nvim.is_laravel_project = true

        -- Show notification if enabled
        if config.notifications then
            vim.notify("Laravel.nvim: Laravel project detected at " .. project_root, vim.log.levels.INFO)
        end

        -- Setup modules only if in Laravel project
        if config.keymaps then
            require('laravel.keymaps').setup()
        end
        require('laravel.routes').setup()
        require('laravel.artisan').setup()
        require('laravel.composer').setup()
        require('laravel.blade').setup()
        require('laravel.models').setup()
        require('laravel.migrations').setup()
        require('laravel.completions').setup()
        require('laravel.blink_source').setup()
        require('laravel.ide_helper').setup()
        require('laravel.sail').setup()
    else
        _G.laravel_nvim.is_laravel_project = false
        -- Show non-Laravel notification if enabled
        if config.notifications then
            vim.notify("Laravel.nvim: Not in Laravel project - components not loaded", vim.log.levels.INFO)
        end
    end

    -- Add command to manually set Laravel project root
    vim.api.nvim_create_user_command('LaravelSetRoot', function(opts)
        local new_root = opts.args
        if new_root == '' then
            new_root = vim.fn.input('Laravel project root: ', vim.fn.getcwd(), 'dir')
        end

        if new_root == '' then
            return
        end

        -- Expand path and check if it exists
        new_root = vim.fn.expand(new_root)
        if vim.fn.isdirectory(new_root) == 0 then
            vim.notify('Directory does not exist: ' .. new_root, vim.log.levels.ERROR)
            return
        end

        -- Check if it looks like a Laravel project
        local laravel_markers = { 'artisan', 'composer.json', 'app/Http/Kernel.php' }
        local is_laravel = false
        for _, marker in ipairs(laravel_markers) do
            if vim.fn.filereadable(new_root .. '/' .. marker) == 1 then
                is_laravel = true
                break
            end
        end

        if not is_laravel then
            vim.ui.input({
                prompt = 'Directory does not look like a Laravel project. Set anyway? (y/N): ',
                default = 'n'
            }, function(input)
                if input and (input:lower() == 'y' or input:lower() == 'yes') then
                    _G.laravel_nvim.project_root = new_root
                    _G.laravel_nvim.is_laravel_project = true
                    vim.notify('Laravel project root set to: ' .. new_root, vim.log.levels.INFO)
                end
            end)
        else
            _G.laravel_nvim.project_root = new_root
            _G.laravel_nvim.is_laravel_project = true
            vim.notify('Laravel project root set to: ' .. new_root, vim.log.levels.INFO)
        end
    end, {
        nargs = '?',
        complete = 'dir',
        desc = 'Manually set the Laravel project root directory'
    })

    -- Add command to show current Laravel project info
    vim.api.nvim_create_user_command('LaravelStatus', function()
        print("=== Laravel.nvim Status ===")
        print("Setup called: " .. (_G.laravel_nvim.setup_called and "YES" or "NO"))
        print("Project root: " .. (_G.laravel_nvim.project_root or "NOT SET"))
        print("Is Laravel project: " .. (_G.laravel_nvim.is_laravel_project and "YES" or "NO"))
        print("Current working directory: " .. vim.fn.getcwd())
        print("=== End Status ===")
    end, {
        desc = 'Show Laravel.nvim status and configuration'
    })
end

return M
