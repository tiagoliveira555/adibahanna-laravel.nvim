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
end

return M
