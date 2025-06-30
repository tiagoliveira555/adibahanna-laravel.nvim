-- Laravel Artisan command integration
local M = {}

local Job = require('laravel.utils.job')
local ui = require('laravel.ui')
local sail = require('laravel.sail')

-- Cache for artisan command list
local artisan_cache = {}
local cache_timestamp = 0
local cache_duration = 300 -- 5 minutes

-- Get Laravel project root
local function get_project_root()
    return _G.laravel_nvim.project_root
end

-- Check if artisan is available
local function is_artisan_available()
    local root = get_project_root()
    if not root then return false end

    local artisan_path = root .. '/artisan'
    return vim.fn.filereadable(artisan_path) == 1
end

-- Parse artisan command output to extract available commands
local function parse_artisan_list(output)
    local commands = {}
    local in_available_commands = false

    for line in output:gmatch("[^\r\n]+") do
        -- Look for the "Available commands:" section
        if line:match("Available commands:") then
            in_available_commands = true
        elseif in_available_commands then
            -- Parse command lines (format: "  command:name    Description")
            local cmd = line:match("^%s+([%w:%-_]+)")
            if cmd then
                commands[#commands + 1] = cmd
            elseif line:match("^[A-Za-z]") then
                -- New section started, stop parsing commands
                break
            end
        end
    end

    return commands
end

-- Get list of available artisan commands
local function get_artisan_commands()
    local current_time = os.time()

    -- Use cache if available and not expired
    if artisan_cache.commands and (current_time - cache_timestamp) < cache_duration then
        return artisan_cache.commands
    end

    if not is_artisan_available() then
        return {}
    end

    local root = get_project_root()
    local artisan_cmd = sail.wrap_command('php artisan list --format=txt')
    local cmd = 'cd ' .. vim.fn.shellescape(root) .. ' && ' .. artisan_cmd

    local output = vim.fn.system(cmd)
    if vim.v.shell_error == 0 then
        local commands = parse_artisan_list(output)

        -- Update cache
        artisan_cache.commands = commands
        cache_timestamp = current_time

        return commands
    else
        vim.notify('Failed to get artisan commands: ' .. output, vim.log.levels.ERROR)
        return {}
    end
end

-- Get artisan make command completions
local function get_make_commands()
    local commands = get_artisan_commands()
    local make_commands = {}

    for _, cmd in ipairs(commands) do
        if cmd:match("^make:") then
            make_commands[#make_commands + 1] = cmd:gsub("^make:", "")
        end
    end

    return make_commands
end

-- Run artisan command
function M.run_command(args)
    if not is_artisan_available() then
        vim.notify('Artisan not found. Are you in a Laravel project?', vim.log.levels.ERROR)
        return
    end

    local root = get_project_root()
    local artisan_cmd = sail.wrap_command('php artisan ' .. (args or ''))

    -- Open terminal and run command
    local terminal_cmd = 'cd ' .. vim.fn.shellescape(root) .. ' && ' .. artisan_cmd

    -- Create a new split and run the command
    vim.cmd('split')
    vim.cmd('terminal ' .. terminal_cmd)
    vim.cmd('startinsert')
end

-- Interactive artisan make command
function M.make_command(args)
    if not args or args == '' then
        -- Show available make commands with fuzzy finder
        local make_commands = get_make_commands()
        if #make_commands == 0 then
            vim.notify('No make commands available', vim.log.levels.WARN)
            return
        end

        ui.select(make_commands, {
            prompt = 'Select make command:',
            kind = 'artisan_make',
        }, function(choice)
            if choice then
                local name = vim.fn.input('Enter name: ')
                if name and name ~= '' then
                    M.run_command('make:' .. choice .. ' ' .. name)
                end
            end
        end)
    else
        M.run_command('make:' .. args)
    end
end

-- Get completions for artisan commands
function M.get_completions()
    return get_artisan_commands()
end

-- Get completions for make commands
function M.get_make_completions(arg_lead)
    local make_commands = get_make_commands()
    local filtered = {}

    for _, cmd in ipairs(make_commands) do
        if not arg_lead or cmd:match('^' .. vim.pesc(arg_lead)) then
            filtered[#filtered + 1] = cmd
        end
    end

    return filtered
end

-- Run artisan command with output capture
function M.run_command_silent(cmd, callback)
    if not is_artisan_available() then
        if callback then callback(false, 'Artisan not available') end
        return
    end

    local root = get_project_root()
    local artisan_cmd = sail.wrap_command('php artisan ' .. cmd)
    local full_cmd = 'cd ' .. vim.fn.shellescape(root) .. ' && ' .. artisan_cmd

    Job.run(full_cmd, {
        on_complete = function(success, output)
            if callback then
                callback(success, output)
            end
        end
    })
end

-- Get route list
function M.get_routes(callback)
    M.run_command_silent('route:list --json', function(success, output)
        if success then
            local ok, routes = pcall(vim.json.decode, output)
            if ok then
                callback(routes)
            else
                vim.notify('Failed to parse routes JSON', vim.log.levels.ERROR)
                callback({})
            end
        else
            vim.notify('Failed to get routes: ' .. output, vim.log.levels.ERROR)
            callback({})
        end
    end)
end

-- Clear artisan command cache
function M.clear_cache()
    artisan_cache = {}
    cache_timestamp = 0
end

-- Setup function
function M.setup()
    -- Pre-populate cache in background
    vim.defer_fn(function()
        get_artisan_commands()
    end, 100)
end

return M
