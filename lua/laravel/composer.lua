-- Laravel Composer command integration
local M = {}

local Job = require('laravel.utils.job')
local ui = require('laravel.ui')
local sail = require('laravel.sail')

-- Cache for composer command list
local composer_cache = {}
local cache_timestamp = 0
local cache_duration = 300 -- 5 minutes

-- Get Laravel project root
local function get_project_root()
    return _G.laravel_nvim.project_root
end

-- Check if composer is available
local function is_composer_available()
    local root = get_project_root()
    if not root then return false end

    local composer_json_path = root .. '/composer.json'
    return vim.fn.filereadable(composer_json_path) == 1
end

-- Parse composer command output to extract available commands
local function parse_composer_list(output)
    local commands = {}
    local in_available_commands = false

    for line in output:gmatch("[^\r\n]+") do
        -- Look for the "Available commands:" section
        if line:match("Available commands:") then
            in_available_commands = true
        elseif in_available_commands then
            -- Parse command lines (format: "  command    Description")
            local cmd = line:match("^%s+([%w:%-_]+)")
            if cmd and not cmd:match("^help$") and not cmd:match("^list$") then
                commands[#commands + 1] = cmd
            elseif line:match("^[A-Za-z]") and not line:match("^%s") then
                -- New section started, stop parsing commands
                break
            end
        end
    end

    return commands
end

-- Get list of available composer commands
local function get_composer_commands()
    local current_time = os.time()

    -- Use cache if available and not expired
    if composer_cache.commands and (current_time - cache_timestamp) < cache_duration then
        return composer_cache.commands
    end

    if not is_composer_available() then
        return {}
    end

    local root = get_project_root()
    local composer_cmd = sail.wrap_command('composer list --format=txt')
    local cmd = 'cd ' .. vim.fn.shellescape(root) .. ' && ' .. composer_cmd

    local output = vim.fn.system(cmd)
    if vim.v.shell_error == 0 then
        local commands = parse_composer_list(output)

        -- Add common composer commands that might not appear in list
        local common_commands = {
            'install', 'update', 'require', 'remove', 'dump-autoload', 'dumpautoload',
            'show', 'outdated', 'validate', 'status', 'self-update', 'clear-cache',
            'diagnose', 'why', 'why-not', 'depends', 'prohibits'
        }

        for _, common_cmd in ipairs(common_commands) do
            local found = false
            for _, cmd in ipairs(commands) do
                if cmd == common_cmd then
                    found = true
                    break
                end
            end
            if not found then
                commands[#commands + 1] = common_cmd
            end
        end

        -- Update cache
        composer_cache.commands = commands
        cache_timestamp = current_time

        return commands
    else
        -- Return common commands as fallback
        local fallback_commands = {
            'install', 'update', 'require', 'remove', 'dump-autoload', 'dumpautoload',
            'show', 'outdated', 'validate', 'status', 'self-update', 'clear-cache'
        }
        return fallback_commands
    end
end



-- Run composer command
function M.run_command(args)
    if not is_composer_available() then
        vim.notify('composer.json not found. Are you in a Laravel project?', vim.log.levels.ERROR)
        return
    end

    local root = get_project_root()
    local composer_cmd = sail.wrap_command('composer ' .. (args or ''))

    -- Open terminal and run command
    local terminal_cmd = 'cd ' .. vim.fn.shellescape(root) .. ' && ' .. composer_cmd

    -- Create a new split and run the command
    vim.cmd('split')
    vim.cmd('terminal ' .. terminal_cmd)
    vim.cmd('startinsert')
end

-- Interactive composer require command
function M.require_command(args)
    if not args or args == '' then
        local package = vim.fn.input('Package name: ')
        if package and package ~= '' then
            local version = vim.fn.input('Version constraint (optional): ')
            local dev_flag = vim.fn.confirm('Install as dev dependency?', '&Yes\n&No', 2)
            local dev_option = dev_flag == 1 and ' --dev' or ''
            local version_part = version and version ~= '' and ':' .. version or ''
            M.run_command('require ' .. package .. version_part .. dev_option)
        end
    else
        M.run_command('require ' .. args)
    end
end

-- Interactive composer remove command
function M.remove_command(args)
    if not args or args == '' then
        -- Get installed packages
        M.get_installed_packages(function(packages)
            if #packages == 0 then
                vim.notify('No packages found to remove', vim.log.levels.WARN)
                return
            end

            ui.select(packages, {
                prompt = 'Select package to remove:',
                kind = 'composer_remove',
            }, function(choice)
                if choice then
                    M.run_command('remove ' .. choice)
                end
            end)
        end)
    else
        M.run_command('remove ' .. args)
    end
end

-- Get completions for composer commands
function M.get_completions()
    return get_composer_commands()
end

-- Get require completions (empty since we don't need hardcoded suggestions)
function M.get_require_completions(arg_lead)
    return {}
end

-- Run composer command with output capture
function M.run_command_silent(cmd, callback)
    if not is_composer_available() then
        if callback then callback(false, 'Composer not available') end
        return
    end

    local root = get_project_root()
    local composer_cmd = sail.wrap_command('composer ' .. cmd)
    local full_cmd = 'cd ' .. vim.fn.shellescape(root) .. ' && ' .. composer_cmd

    Job.run(full_cmd, {
        on_complete = function(success, output)
            if callback then
                callback(success, output)
            end
        end
    })
end

-- Get installed packages
function M.get_installed_packages(callback)
    M.run_command_silent('show --name-only', function(success, output)
        if success then
            local packages = {}
            for line in output:gmatch("[^\r\n]+") do
                local package = line:match("^([%w%-_/]+)")
                if package then
                    packages[#packages + 1] = package
                end
            end
            callback(packages)
        else
            vim.notify('Failed to get installed packages: ' .. output, vim.log.levels.ERROR)
            callback({})
        end
    end)
end

-- Get outdated packages
function M.get_outdated_packages(callback)
    M.run_command_silent('outdated --format=json', function(success, output)
        if success then
            local ok, data = pcall(vim.json.decode, output)
            if ok and data.installed then
                callback(data.installed)
            else
                vim.notify('Failed to parse outdated packages', vim.log.levels.ERROR)
                callback({})
            end
        else
            vim.notify('Failed to get outdated packages: ' .. output, vim.log.levels.ERROR)
            callback({})
        end
    end)
end

-- Show project dependencies
function M.show_dependencies()
    M.run_command_silent('show --tree', function(success, output)
        if success then
            vim.cmd('new')
            vim.bo.buftype = 'nofile'
            vim.bo.bufhidden = 'wipe'
            vim.bo.swapfile = false
            vim.bo.filetype = 'text'
            vim.api.nvim_buf_set_name(0, 'Composer Dependencies')

            local lines = {}
            for line in output:gmatch("[^\r\n]+") do
                table.insert(lines, line)
            end
            vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
            vim.bo.modifiable = false
        else
            vim.notify('Failed to show dependencies: ' .. output, vim.log.levels.ERROR)
        end
    end)
end

-- Clear composer command cache
function M.clear_cache()
    composer_cache = {}
    cache_timestamp = 0
end

-- Setup function
function M.setup()
    -- Pre-populate cache in background
    vim.defer_fn(function()
        get_composer_commands()
    end, 200)
end

return M
