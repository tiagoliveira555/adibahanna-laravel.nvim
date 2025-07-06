-- Laravel.nvim - A comprehensive Laravel development plugin for Neovim
-- Main plugin entry point

if vim.g.loaded_laravel_nvim then
    return
end
vim.g.loaded_laravel_nvim = true

local sail = require('laravel.sail')

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
        require('laravel.composer').setup()
        require('laravel.blade').setup()
        require('laravel.routes').setup()
        require('laravel.models').setup()
        require('laravel.migrations').setup()
        -- Only setup keymaps if enabled (default true, but respects user config)
        local keymaps_enabled = _G.laravel_nvim.config and _G.laravel_nvim.config.keymaps
        if keymaps_enabled == nil then
            keymaps_enabled = true -- Default to true if not configured
        end
        if keymaps_enabled then
            require('laravel.keymaps').setup() -- Laravel-specific keymaps
        end
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

    -- Initialize when entering any buffer (for global command availability)
    vim.api.nvim_create_autocmd({ 'BufRead', 'BufNewFile' }, {
        group = group,
        pattern = '*',
        callback = function()
            -- Only initialize if we haven't checked for Laravel project yet
            if _G.laravel_nvim.project_root == nil and not _G.laravel_nvim.setup_called then
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

-- Check if in Laravel project (with fallback detection)
local function is_in_laravel_project()
    -- Try global state first
    if _G.laravel_nvim and _G.laravel_nvim.is_laravel_project then
        return true
    end

    -- Fallback: detect Laravel project directly
    local function find_laravel_root()
        local current_dir = vim.fn.getcwd()
        local function check_laravel_markers(dir)
            local markers = { 'artisan', 'composer.json' }
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
                return true
            end
            dir = vim.fn.fnamemodify(dir, ':h')
        end
        return false
    end

    return find_laravel_root()
end

-- Setup user commands
local function setup_commands()
    -- Artisan command (always available)
    vim.api.nvim_create_user_command('Artisan', function(opts)
        if not is_in_laravel_project() then
            vim.notify('Not in a Laravel project', vim.log.levels.ERROR)
            return
        end
        require('laravel.artisan').run_command(opts.args)
    end, {
        nargs = '*',
        complete = function()
            if not is_in_laravel_project() then
                return {}
            end
            return require('laravel.artisan').get_completions()
        end,
        desc = 'Run Laravel Artisan commands'
    })

    -- Composer command (always available)
    vim.api.nvim_create_user_command('Composer', function(opts)
        if not is_in_laravel_project() then
            vim.notify('Not in a Laravel project', vim.log.levels.ERROR)
            return
        end
        require('laravel.composer').run_command(opts.args)
    end, {
        nargs = '*',
        complete = function()
            if not is_in_laravel_project() then
                return {}
            end
            return require('laravel.composer').get_completions()
        end,
        desc = 'Run Composer commands'
    })

    -- Composer require command with package suggestions
    vim.api.nvim_create_user_command('ComposerRequire', function(opts)
        if not is_in_laravel_project() then
            vim.notify('Not in a Laravel project', vim.log.levels.ERROR)
            return
        end
        require('laravel.composer').require_command(opts.args)
    end, {
        nargs = '*',
        complete = function(arg_lead)
            if not is_in_laravel_project() then
                return {}
            end
            return require('laravel.composer').get_require_completions(arg_lead)
        end,
        desc = 'Composer require with package suggestions'
    })

    -- Composer remove command with installed package selection
    vim.api.nvim_create_user_command('ComposerRemove', function(opts)
        if not is_in_laravel_project() then
            vim.notify('Not in a Laravel project', vim.log.levels.ERROR)
            return
        end
        require('laravel.composer').remove_command(opts.args)
    end, {
        nargs = '*',
        desc = 'Composer remove with installed package selection'
    })

    -- Show composer dependencies
    vim.api.nvim_create_user_command('ComposerDependencies', function()
        if not is_in_laravel_project() then
            vim.notify('Not in a Laravel project', vim.log.levels.ERROR)
            return
        end
        require('laravel.composer').show_dependencies()
    end, { desc = 'Show composer project dependencies' })

    -- Laravel-specific navigation commands (always available)
    vim.api.nvim_create_user_command('LaravelController', function(opts)
        if not is_in_laravel_project() then
            vim.notify('Not in a Laravel project', vim.log.levels.ERROR)
            return
        end
        require('laravel.navigate').goto_controller(opts.args)
    end, { nargs = '?', desc = 'Navigate to Laravel controller' })

    vim.api.nvim_create_user_command('LaravelModel', function(opts)
        if not is_in_laravel_project() then
            vim.notify('Not in a Laravel project', vim.log.levels.ERROR)
            return
        end
        require('laravel.navigate').goto_model(opts.args)
    end, { nargs = '?', desc = 'Navigate to Laravel model' })

    vim.api.nvim_create_user_command('LaravelView', function(opts)
        if not is_in_laravel_project() then
            vim.notify('Not in a Laravel project', vim.log.levels.ERROR)
            return
        end
        require('laravel.navigate').goto_view(opts.args)
    end, { nargs = '?', desc = 'Navigate to Laravel view' })

    -- Laravel goto definition command (equivalent to gd keymap)
    vim.api.nvim_create_user_command('LaravelGoto', function()
        if not is_in_laravel_project() then
            vim.notify('Not in a Laravel project', vim.log.levels.ERROR)
            return
        end

        local navigate = require('laravel.navigate')
        if navigate.is_laravel_navigation_context() then
            -- This is a Laravel-specific context, try Laravel navigation
            local success = pcall(navigate.goto_laravel_string)
            if success then
                return -- Laravel navigation succeeded
            end
        end

        -- Default to LSP definition for everything else
        if vim.lsp.buf.definition then
            vim.lsp.buf.definition()
        else
            vim.notify('No LSP definition available', vim.log.levels.WARN)
        end
    end, { desc = 'Laravel-aware goto definition (same as gd)' })

    vim.api.nvim_create_user_command('LaravelRoute', function()
        if not is_in_laravel_project() then
            vim.notify('Not in a Laravel project', vim.log.levels.ERROR)
            return
        end
        require('laravel.routes').show_routes()
    end, { desc = 'Show Laravel routes' })

    vim.api.nvim_create_user_command('LaravelMake', function(opts)
        if not is_in_laravel_project() then
            vim.notify('Not in a Laravel project', vim.log.levels.ERROR)
            return
        end
        require('laravel.artisan').make_command(opts.args)
    end, {
        nargs = '*',
        complete = function(arg_lead)
            if not is_in_laravel_project() then
                return {}
            end
            return require('laravel.artisan').get_make_completions(arg_lead)
        end,
        desc = 'Laravel make commands with fuzzy finder'
    })

    -- Schema diagram commands (always available)
    vim.api.nvim_create_user_command('LaravelSchema', function()
        if not is_in_laravel_project() then
            vim.notify('Not in a Laravel project', vim.log.levels.ERROR)
            return
        end
        require('laravel.schema').show_schema_diagram(false)
    end, { desc = 'Show Laravel database schema diagram' })

    vim.api.nvim_create_user_command('LaravelSchemaExport', function()
        if not is_in_laravel_project() then
            vim.notify('Not in a Laravel project', vim.log.levels.ERROR)
            return
        end
        require('laravel.schema').show_schema_diagram(true)
    end, { desc = 'Export Laravel database schema diagram to file' })

    -- Architecture diagram commands (always available)
    vim.api.nvim_create_user_command('LaravelArchitecture', function()
        if not is_in_laravel_project() then
            vim.notify('Not in a Laravel project', vim.log.levels.ERROR)
            return
        end
        require('laravel.architecture').show_architecture_diagram()
    end, { desc = 'Show Laravel application architecture diagram' })

    -- Completion management commands (always available)
    vim.api.nvim_create_user_command('LaravelCompletions', function(opts)
        if not is_in_laravel_project() then
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
        if not is_in_laravel_project() then
            vim.notify('Not in a Laravel project', vim.log.levels.ERROR)
            return
        end
        require('laravel.completions').clear_cache()
        require('laravel.composer').clear_cache()
        local ok, ide_helper = pcall(require, 'laravel.ide_helper')
        if ok then
            ide_helper.clear_cache()
        end
        vim.notify('Laravel completion, composer, and IDE helper cache cleared', vim.log.levels.INFO)
    end, { desc = 'Clear Laravel completion, composer, and IDE helper cache' })

    -- Laravel IDE Helper installation command
    vim.api.nvim_create_user_command('LaravelInstallIdeHelper', function()
        if not is_in_laravel_project() then
            vim.notify('Not in a Laravel project', vim.log.levels.ERROR)
            return
        end

        local root = _G.laravel_nvim.project_root

        vim.notify('Installing Laravel IDE Helper...', vim.log.levels.INFO)
        local result = vim.fn.system('cd ' .. root .. ' && composer require --dev barryvdh/laravel-ide-helper')

        if vim.v.shell_error ~= 0 then
            vim.notify('Failed to install Laravel IDE Helper:\n' .. result, vim.log.levels.ERROR)
            return
        end

        vim.notify('Laravel IDE Helper installed successfully!', vim.log.levels.INFO)

        -- Ask if user wants to generate files now
        local choice = vim.fn.confirm(
            'Generate IDE Helper files now?',
            '&Yes\n&No',
            1
        )

        if choice == 1 then
            vim.cmd('LaravelIdeHelper all')
        end
    end, { desc = 'Install Laravel IDE Helper package' })

    -- Remove only the generated IDE Helper files (keep package)
    vim.api.nvim_create_user_command('LaravelIdeHelperClean', function()
        if not is_in_laravel_project() then
            vim.notify('Not in a Laravel project', vim.log.levels.ERROR)
            return
        end

        local root = _G.laravel_nvim.project_root

        local choice = vim.fn.confirm(
            'Remove generated IDE Helper files?\n\nThis will delete:\n• _ide_helper.php\n• _ide_helper_models.php\n• .phpstorm.meta.php\n\nThe composer package will remain installed.',
            '&Yes\n&No',
            2 -- Default to No
        )

        if choice ~= 1 then
            return
        end

        -- Remove generated files
        local files_to_remove = {
            root .. '/_ide_helper.php',
            root .. '/_ide_helper_models.php',
            root .. '/.phpstorm.meta.php'
        }

        local removed_count = 0
        for _, file in ipairs(files_to_remove) do
            if vim.fn.filereadable(file) == 1 then
                vim.fn.delete(file)
                vim.notify('Deleted: ' .. vim.fn.fnamemodify(file, ':t'), vim.log.levels.INFO)
                removed_count = removed_count + 1
            end
        end

        if removed_count == 0 then
            vim.notify('No IDE Helper files found to remove', vim.log.levels.WARN)
        else
            -- Clear IDE helper cache
            local ok, ide_helper = pcall(require, 'laravel.ide_helper')
            if ok then
                ide_helper.clear_cache()
            end
            vim.notify('IDE Helper files cleaned! (' .. removed_count .. ' files removed)', vim.log.levels.INFO)
        end
    end, { desc = 'Remove generated IDE Helper files (keep package)' })

    -- Remove Laravel IDE Helper completely
    vim.api.nvim_create_user_command('LaravelRemoveIdeHelper', function()
        if not is_in_laravel_project() then
            vim.notify('Not in a Laravel project', vim.log.levels.ERROR)
            return
        end

        local root = _G.laravel_nvim.project_root
        local composer_json = root .. '/composer.json'

        -- Check if IDE Helper is installed
        local is_installed = false
        if vim.fn.filereadable(composer_json) == 1 then
            local content = vim.fn.readfile(composer_json)
            local json_str = table.concat(content, '\n')
            is_installed = json_str:find('"barryvdh/laravel%-ide%-helper"') ~= nil
        end

        if not is_installed then
            vim.notify('Laravel IDE Helper is not installed', vim.log.levels.WARN)
            return
        end

        local choice = vim.fn.confirm(
            'Remove Laravel IDE Helper completely?\n\nThis will:\n• Remove the composer package\n• Delete all generated helper files\n• Clear completion cache',
            '&Yes\n&No',
            2 -- Default to No
        )

        if choice ~= 1 then
            return
        end

        -- Remove the composer package (from dev dependencies)
        vim.notify('Removing Laravel IDE Helper package...', vim.log.levels.INFO)
        local result = vim.fn.system('cd ' .. root .. ' && composer remove --dev barryvdh/laravel-ide-helper 2>&1')

        -- Check if the package was actually removed by checking composer.json again
        local composer_content = vim.fn.readfile(composer_json)
        local composer_str = table.concat(composer_content, '\n')
        local still_present = composer_str:find('"barryvdh/laravel%-ide%-helper"') ~= nil

        if still_present then
            vim.notify('Package removal may have failed. Checking dependencies...', vim.log.levels.WARN)

            -- Try to find out why it might still be there
            local why_result = vim.fn.system('cd ' .. root .. ' && composer why barryvdh/laravel-ide-helper 2>&1')

            vim.notify(
                'Laravel IDE Helper package could not be completely removed.\n\nReason:\n' ..
                why_result ..
                '\n\nYou may need to manually run:\ncomposer remove --dev barryvdh/laravel-ide-helper\n\nContinuing to remove generated files...',
                vim.log.levels.ERROR)
        else
            vim.notify('Package removed successfully!', vim.log.levels.INFO)
        end

        -- Remove generated files
        local files_to_remove = {
            root .. '/_ide_helper.php',
            root .. '/_ide_helper_models.php',
            root .. '/.phpstorm.meta.php'
        }

        for _, file in ipairs(files_to_remove) do
            if vim.fn.filereadable(file) == 1 then
                vim.fn.delete(file)
                vim.notify('Deleted: ' .. vim.fn.fnamemodify(file, ':t'), vim.log.levels.INFO)
            end
        end

        -- Clear IDE helper cache
        local ok, ide_helper = pcall(require, 'laravel.ide_helper')
        if ok then
            ide_helper.clear_cache()
        end

        vim.notify('Laravel IDE Helper completely removed!', vim.log.levels.INFO)
    end, { desc = 'Completely remove Laravel IDE Helper package and files' })

    -- Check IDE Helper status command
    vim.api.nvim_create_user_command('LaravelIdeHelperCheck', function()
        if not is_in_laravel_project() then
            vim.notify('Not in a Laravel project', vim.log.levels.ERROR)
            return
        end

        local root = _G.laravel_nvim.project_root
        local composer_json = root .. '/composer.json'

        -- Check if IDE Helper is installed
        local is_installed = false
        if vim.fn.filereadable(composer_json) == 1 then
            local content = vim.fn.readfile(composer_json)
            local json_str = table.concat(content, '\n')
            is_installed = json_str:find('"barryvdh/laravel%-ide%-helper"') ~= nil
        end

        if not is_installed then
            vim.notify('Laravel IDE Helper not installed. Run :LaravelInstallIdeHelper to install.', vim.log.levels.WARN)
            return
        end

        -- Check for helper files
        local files = {
            { path = root .. '/_ide_helper.php',        name = 'main helper' },
            { path = root .. '/_ide_helper_models.php', name = 'models' },
            { path = root .. '/.phpstorm.meta.php',     name = 'meta' }
        }

        local missing = {}
        for _, file in ipairs(files) do
            if vim.fn.filereadable(file.path) == 0 then
                table.insert(missing, file.name)
            end
        end

        if #missing > 0 then
            local choice = vim.fn.confirm(
                'IDE Helper files missing: ' .. table.concat(missing, ', ') .. '\nGenerate them now?',
                '&Yes\n&No',
                1
            )
            if choice == 1 then
                vim.cmd('LaravelIdeHelper all')
            end
        else
            vim.notify('All IDE Helper files are present!', vim.log.levels.INFO)
        end
    end, { desc = 'Check Laravel IDE Helper status and files' })

    -- IDE Helper management commands
    vim.api.nvim_create_user_command('LaravelIdeHelper', function(opts)
        if not is_in_laravel_project() then
            vim.notify('Not in a Laravel project', vim.log.levels.ERROR)
            return
        end

        local action = opts.args or 'generate'
        local root = _G.laravel_nvim.project_root

        local commands = {
            generate = sail.wrap_command('php artisan ide-helper:generate'),
            models = sail.wrap_command('php artisan ide-helper:models --write'),
            meta = sail.wrap_command('php artisan ide-helper:meta'),
            all = {
                sail.wrap_command('php artisan ide-helper:generate'),
                sail.wrap_command('php artisan ide-helper:models --write'),
                sail.wrap_command('php artisan ide-helper:meta')
            }
        }

        local cmd_list = commands[action]
        if not cmd_list then
            vim.notify('Unknown action: ' .. action .. '\nAvailable: generate, models, meta, all', vim.log.levels.ERROR)
            return
        end

        if type(cmd_list) == 'string' then
            cmd_list = { cmd_list }
        end

        for _, cmd in ipairs(cmd_list) do
            vim.notify('Running: ' .. cmd, vim.log.levels.INFO)
            local result = vim.fn.system('cd ' .. root .. ' && ' .. cmd)
            if vim.v.shell_error ~= 0 then
                vim.notify('Failed to run: ' .. cmd .. '\n' .. result, vim.log.levels.ERROR)
                return
            end
        end

        vim.notify('IDE Helper files generated successfully!', vim.log.levels.INFO)

        -- Clear cache after generation
        local ok, ide_helper = pcall(require, 'laravel.ide_helper')
        if ok then
            ide_helper.clear_cache()
        end
    end, {
        nargs = '?',
        complete = function()
            return { 'generate', 'models', 'meta', 'all' }
        end,
        desc = 'Generate Laravel IDE Helper files'
    })

    -- Laravel Sail Commands
    vim.api.nvim_create_user_command('Sail', function(opts)
        if not is_in_laravel_project() then
            vim.notify('Not in a Laravel project', vim.log.levels.ERROR)
            return
        end
        require('laravel.sail').run_command(opts.args)
    end, {
        nargs = '*',
        complete = function(arg_lead, cmd_line, cursor_pos)
            if not is_in_laravel_project() then
                return {}
            end

            -- Common Sail commands for autocompletion
            local sail_commands = {
                'up', 'down', 'stop', 'restart',
                'artisan', 'composer', 'php', 'node', 'npm', 'yarn',
                'shell', 'root-shell',
                'logs', 'ps', 'exec',
                'test', 'dusk', 'tinker',
                'share', 'build', 'rebuild'
            }

            local matches = {}
            for _, cmd in ipairs(sail_commands) do
                if not arg_lead or cmd:match('^' .. vim.pesc(arg_lead)) then
                    matches[#matches + 1] = cmd
                end
            end

            return matches
        end,
        desc = 'Run Laravel Sail commands'
    })

    vim.api.nvim_create_user_command('SailUp', function(opts)
        if not is_in_laravel_project() then
            vim.notify('Not in a Laravel project', vim.log.levels.ERROR)
            return
        end
        require('laravel.sail').up(opts.args)
    end, {
        nargs = '*',
        desc = 'Start Laravel Sail containers'
    })

    vim.api.nvim_create_user_command('SailDown', function(opts)
        if not is_in_laravel_project() then
            vim.notify('Not in a Laravel project', vim.log.levels.ERROR)
            return
        end
        require('laravel.sail').down(opts.args)
    end, {
        nargs = '*',
        desc = 'Stop Laravel Sail containers'
    })

    vim.api.nvim_create_user_command('SailRestart', function()
        if not is_in_laravel_project() then
            vim.notify('Not in a Laravel project', vim.log.levels.ERROR)
            return
        end
        require('laravel.sail').restart()
    end, { desc = 'Restart Laravel Sail containers' })

    vim.api.nvim_create_user_command('SailTest', function(opts)
        if not is_in_laravel_project() then
            vim.notify('Not in a Laravel project', vim.log.levels.ERROR)
            return
        end
        require('laravel.sail').test(opts.args)
    end, {
        nargs = '*',
        desc = 'Run tests through Laravel Sail'
    })

    vim.api.nvim_create_user_command('SailShare', function(opts)
        if not is_in_laravel_project() then
            vim.notify('Not in a Laravel project', vim.log.levels.ERROR)
            return
        end
        require('laravel.sail').share(opts.args)
    end, {
        nargs = '?',
        desc = 'Share Laravel application via Sail'
    })

    vim.api.nvim_create_user_command('SailShell', function(opts)
        if not is_in_laravel_project() then
            vim.notify('Not in a Laravel project', vim.log.levels.ERROR)
            return
        end
        if opts.args and opts.args ~= '' then
            require('laravel.sail').shell(opts.args)
        else
            require('laravel.sail').select_service_and_run('shell')
        end
    end, {
        nargs = '?',
        desc = 'Open shell in Laravel Sail container'
    })

    vim.api.nvim_create_user_command('SailLogs', function(opts)
        if not is_in_laravel_project() then
            vim.notify('Not in a Laravel project', vim.log.levels.ERROR)
            return
        end
        if opts.args and opts.args ~= '' then
            require('laravel.sail').logs(opts.args)
        else
            require('laravel.sail').select_service_and_run('logs')
        end
    end, {
        nargs = '?',
        desc = 'View Laravel Sail container logs'
    })

    vim.api.nvim_create_user_command('SailStatus', function()
        if not is_in_laravel_project() then
            vim.notify('Not in a Laravel project', vim.log.levels.ERROR)
            return
        end
        require('laravel.sail').status()
    end, { desc = 'Check Laravel Sail status' })

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

        -- Check Sail status
        local sail_available = require('laravel.sail').is_sail_available()
        if sail_available then
            vim.notify("Laravel Sail is available 🐳", vim.log.levels.INFO)
        else
            vim.notify("Laravel Sail not detected", vim.log.levels.INFO)
        end
    end, { desc = 'Check Laravel.nvim status' })

    vim.api.nvim_create_user_command('SailStop', function(opts)
        if not is_in_laravel_project() then
            vim.notify('Not in a Laravel project', vim.log.levels.ERROR)
            return
        end
        require('laravel.sail').run_command('stop')
    end, {
        desc = 'Stop all Sail containers (docker stop)',
    })

    vim.api.nvim_create_user_command('SailOpen', function()
        if not is_in_laravel_project() then
            vim.notify('Not in a Laravel project', vim.log.levels.ERROR)
            return
        end
        require('laravel.sail').open()
    end, {
        desc = 'Open Laravel Sail app in browser'
    })

    -- Debug commands for treesitter navigation
    -- vim.api.nvim_create_user_command('LaravelDebugTreesitter', function()
    --     if not is_in_laravel_project() then
    --         vim.notify('Not in a Laravel project', vim.log.levels.ERROR)
    --         return
    --     end
    --     require('laravel.navigate').debug_treesitter_context()
    -- end, {
    --     desc = 'Debug treesitter parsing for Laravel navigation'
    -- })

    -- vim.api.nvim_create_user_command('LaravelCompareParsing', function()
    --     if not is_in_laravel_project() then
    --         vim.notify('Not in a Laravel project', vim.log.levels.ERROR)
    --         return
    --     end
    --     require('laravel.navigate').compare_parsing_methods()
    -- end, {
    --     desc = 'Compare treesitter vs regex parsing methods'
    -- })
end



-- Always setup commands first
setup_commands()

-- Setup autocommands (initialization will happen when setup() is called or on first buffer)
setup_autocommands()

-- Initialize Laravel detection immediately for global commands
vim.defer_fn(function()
    if not _G.laravel_nvim.setup_called then
        initialize_laravel()
    end
end, 100) -- Small delay to allow setup() to be called first
