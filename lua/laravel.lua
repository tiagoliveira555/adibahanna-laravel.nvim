-- Laravel.nvim - Main module
local M = {}

-- Default configuration
local default_config = {
    -- Add any default configuration options here
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

    -- Find and set Laravel project root
    local project_root = find_laravel_project_root()
    if project_root then
        _G.laravel_nvim.project_root = project_root
    else
        return
    end

    -- Setup modules
    require('laravel.keymaps').setup()
    require('laravel.routes').setup()

    -- Setup commands
    vim.api.nvim_create_user_command('LaravelTestCompletions', function()
        local completions = require('laravel.completions')
        completions.test_completions()
    end, { desc = 'Test Laravel completions' })

    vim.api.nvim_create_user_command('LaravelCompletions', function(opts)
        local completions = require('laravel.completions')
        local func_type = opts.args and opts.args ~= '' and opts.args or nil

        if func_type then
            local items = completions.get_completions(func_type, '')
            if #items > 0 then
                vim.notify('Found ' .. #items .. ' ' .. func_type .. ' completions:', vim.log.levels.INFO)
                for i, item in ipairs(math.min(10, #items) == 10 and vim.list_slice(items, 1, 10) or items) do
                    print('  ' .. item)
                end
                if #items > 10 then
                    print('  ... and ' .. (#items - 10) .. ' more')
                end
            else
                vim.notify('No ' .. func_type .. ' completions found', vim.log.levels.WARN)
            end
        else
            completions.test_completions()
        end
    end, {
        nargs = '?',
        complete = function() return { 'route', 'view', 'config', 'trans' } end,
        desc = 'Show Laravel completions for a specific type'
    })

    vim.api.nvim_create_user_command('LaravelClearCache', function()
        local completions = require('laravel.completions')
        completions.clear_cache()
        vim.notify('Laravel completion cache cleared', vim.log.levels.INFO)
    end, { desc = 'Clear Laravel completion cache' })

    vim.api.nvim_create_user_command('LaravelTestNavigation', function()
        local navigate = require('laravel.navigate')

        -- Test navigation patterns
        local test_cases = {
            { line = "return route('dashboard');",         desc = "route('dashboard')" },
            { line = "return Inertia::render('welcome');", desc = "Inertia::render('welcome')" },
            { line = "config('app.name')",                 desc = "config('app.name')" },
            { line = "__('auth.failed')",                  desc = "__('auth.failed')" },
        }

        vim.notify('Testing Laravel navigation patterns:', vim.log.levels.INFO)

        for _, test in ipairs(test_cases) do
            -- Simulate being on that line
            vim.fn.setline('.', test.line)

            local completion_source = require('laravel.completion_source')
            local context = completion_source.get_completion_context(test.line, #test.line)

            if context then
                print('✓ ' .. test.desc .. ' -> detected as ' .. context.func .. '("' .. context.partial .. '")')
            else
                print('✗ ' .. test.desc .. ' -> not detected')
            end
        end
    end, { desc = 'Test Laravel navigation detection' })
end

return M
