-- Laravel Sail integration for Docker-based development environment
local M = {}

local Job = require('laravel.utils.job')
local ui = require('laravel.ui')

-- Get Laravel project root
local function get_project_root()
    -- Try global state first
    if _G.laravel_nvim and _G.laravel_nvim.project_root then
        return _G.laravel_nvim.project_root
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
                return dir
            end
            dir = vim.fn.fnamemodify(dir, ':h')
        end
        return nil
    end

    return find_laravel_root()
end

-- Check if Sail is available and configured
function M.is_sail_available()
    local root = get_project_root()
    if not root then return false end

    -- Check for docker-compose.yml
    local docker_compose_path = root .. '/docker-compose.yml'
    if vim.fn.filereadable(docker_compose_path) == 0 then
        return false
    end

    -- Check for sail script
    local sail_path = root .. '/vendor/bin/sail'
    if vim.fn.filereadable(sail_path) == 0 then
        return false
    end

    -- Optional: Check if laravel/sail is in composer.json
    local composer_json = root .. '/composer.json'
    if vim.fn.filereadable(composer_json) == 1 then
        local content = table.concat(vim.fn.readfile(composer_json), '\n')
        if content:match('"laravel/sail"') then
            return true
        end
    end

    -- If docker-compose.yml and sail script exist, assume Sail is available
    return true
end

-- Check if Sail containers are running
function M.is_sail_running(callback)
    if not M.is_sail_available() then
        if callback then callback(false) end
        return
    end

    local root = get_project_root()
    local cmd = 'cd ' .. vim.fn.shellescape(root) .. ' && ./vendor/bin/sail ps --services --filter status=running'

    Job.run(cmd, {
        on_complete = function(success, output)
            if callback then
                -- If any services are running, Sail is considered running
                local is_running = success and output and output:match('%S')
                callback(is_running)
            end
        end
    })
end

-- Get the appropriate command prefix based on Sail availability and user preference
function M.get_command_prefix()
    if not _G.laravel_nvim.config.sail or not _G.laravel_nvim.config.sail.enabled then
        return ''
    end

    if M.is_sail_available() then
        return './vendor/bin/sail '
    end

    return ''
end

-- Wrap a command with Sail if appropriate
function M.wrap_command(base_command)
    local prefix = M.get_command_prefix()
    if prefix ~= '' then
        return prefix .. base_command
    end
    return base_command
end

-- Run a Sail command directly
function M.run_command(args)
    if not M.is_sail_available() then
        vim.notify('Laravel Sail not available. Ensure docker-compose.yml and vendor/bin/sail exist.',
            vim.log.levels.ERROR)
        return
    end

    local root = get_project_root()
    local cmd = './vendor/bin/sail ' .. (args or '')

    -- Open terminal and run command
    local terminal_cmd = 'cd ' .. vim.fn.shellescape(root) .. ' && ' .. cmd

    -- Create a new split and run the command
    vim.cmd('split')
    vim.cmd('terminal ' .. terminal_cmd)
    vim.cmd('startinsert')
end

-- Start Sail containers
function M.up(args)
    local extra_args = args or ''
    M.run_command('up -d ' .. extra_args)
end

-- Stop Sail containers
function M.down(args)
    local extra_args = args or ''
    M.run_command('down ' .. extra_args)
end

-- Restart Sail containers
function M.restart()
    M.run_command('restart')
end

-- Run tests through Sail
function M.test(args)
    local test_args = args or ''
    M.run_command('test ' .. test_args)
end

-- Share site through Sail
function M.share(subdomain)
    local share_cmd = 'share'
    if subdomain and subdomain ~= '' then
        share_cmd = share_cmd .. ' --subdomain=' .. subdomain
    end
    M.run_command(share_cmd)
end

-- Open Sail shell
function M.shell(service)
    local shell_cmd = 'shell'
    if service and service ~= '' then
        shell_cmd = shell_cmd .. ' ' .. service
    end
    M.run_command(shell_cmd)
end

-- View Sail logs
function M.logs(service)
    local logs_cmd = 'logs'
    if service and service ~= '' then
        logs_cmd = logs_cmd .. ' ' .. service
    else
        logs_cmd = logs_cmd .. ' --follow'
    end
    M.run_command(logs_cmd)
end

-- Get Sail services
function M.get_services(callback)
    if not M.is_sail_available() then
        if callback then callback({}) end
        return
    end

    local root = get_project_root()
    local cmd = 'cd ' .. vim.fn.shellescape(root) .. ' && ./vendor/bin/sail ps --services'

    Job.run(cmd, {
        on_complete = function(success, output)
            if success and output then
                local services = {}
                for line in output:gmatch("[^\r\n]+") do
                    local trimmed = line:match("^%s*(.-)%s*$")
                    if trimmed and trimmed ~= '' then
                        services[#services + 1] = trimmed
                    end
                end
                if callback then callback(services) end
            else
                if callback then callback({}) end
            end
        end
    })
end

-- Check Sail status and show helpful information
function M.status()
    if not M.is_sail_available() then
        vim.notify('Laravel Sail is not available in this project.', vim.log.levels.WARN)
        return
    end

    M.is_sail_running(function(is_running)
        if is_running then
            vim.notify('Laravel Sail is running ✅', vim.log.levels.INFO)

            -- Show running services
            M.get_services(function(services)
                if #services > 0 then
                    vim.notify('Running services: ' .. table.concat(services, ', '), vim.log.levels.INFO)
                end
            end)
        else
            vim.notify('Laravel Sail is not running ⚠️\nRun :SailUp to start containers', vim.log.levels.WARN)
        end
    end)
end

-- Interactive service selection for shell/logs
function M.select_service_and_run(action)
    M.get_services(function(services)
        if #services == 0 then
            vim.notify('No Sail services found', vim.log.levels.WARN)
            return
        end

        ui.select(services, {
            prompt = 'Select service for ' .. action .. ':',
            kind = 'sail_service',
        }, function(choice)
            if choice then
                if action == 'shell' then
                    M.shell(choice)
                elseif action == 'logs' then
                    M.logs(choice)
                end
            end
        end)
    end)
end

-- Setup function
function M.setup()
    -- Check if Sail is available and notify user
    if M.is_sail_available() then
        if _G.laravel_nvim.config.notifications then
            vim.defer_fn(function()
                vim.notify('Laravel Sail detected 🐳', vim.log.levels.INFO)
            end, 1000)
        end
    end
end

return M
