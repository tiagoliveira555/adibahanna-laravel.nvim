-- Laravel string completions system
-- Provides intelligent completions for Laravel helper functions
local M = {}

local ui = require('laravel.ui')
local livewire = require('laravel.livewire')

-- Cache for completions to avoid repeated file parsing
local cache = {
    routes = { data = {}, timestamp = 0 },
    views = { data = {}, timestamp = 0 },
    config = { data = {}, timestamp = 0 },
    translations = { data = {}, timestamp = 0 },
    env = { data = {}, timestamp = 0 },
    livewire = { data = {}, timestamp = 0 },
    wire_directives = { data = {}, timestamp = 0 },
}

local CACHE_TTL = 30 -- seconds

-- Check if cache is valid
local function is_cache_valid(cache_entry)
    return (os.time() - cache_entry.timestamp) < CACHE_TTL
end

-- Get Laravel project root
local function get_project_root()
    return _G.laravel_nvim.project_root
end

-- Extract route names from route files
local function get_route_names()
    if is_cache_valid(cache.routes) then
        return cache.routes.data
    end

    local root = get_project_root()
    if not root then return {} end

    local route_names = {}
    local route_files = {
        root .. '/routes/web.php',
        root .. '/routes/api.php',
        root .. '/routes/auth.php',
        root .. '/routes/channels.php',
        root .. '/routes/console.php'
    }

    for _, route_file in ipairs(route_files) do
        if vim.fn.filereadable(route_file) == 1 then
            local lines = vim.fn.readfile(route_file)
            for _, line in ipairs(lines) do
                -- Match ->name('route.name') patterns
                local name = line:match("->name%s*%(%s*['\"]([^'\"]+)['\"]")
                if name then
                    route_names[#route_names + 1] = name
                end
            end
        end
    end

    -- Remove duplicates and sort
    local unique_names = {}
    local seen = {}
    for _, name in ipairs(route_names) do
        if not seen[name] then
            seen[name] = true
            unique_names[#unique_names + 1] = name
        end
    end
    table.sort(unique_names)

    cache.routes.data = unique_names
    cache.routes.timestamp = os.time()
    return unique_names
end

-- Extract view names from resources/views
local function get_view_names()
    if is_cache_valid(cache.views) then
        return cache.views.data
    end

    local root = get_project_root()
    if not root then return {} end

    local views_path = root .. '/resources/views'
    if vim.fn.isdirectory(views_path) == 0 then
        cache.views.data = {}
        cache.views.timestamp = os.time()
        return {}
    end

    local view_names = {}
    local function scan_views(dir, prefix)
        prefix = prefix or ''
        local items = vim.fn.readdir(dir) or {}

        for _, item in ipairs(items) do
            local full_path = dir .. '/' .. item
            local view_name = prefix .. (prefix ~= '' and '.' or '') .. item

            if vim.fn.isdirectory(full_path) == 1 then
                scan_views(full_path, view_name)
            elseif item:match('%.blade%.php$') then
                view_name = view_name:gsub('%.blade%.php$', '')
                view_names[#view_names + 1] = view_name
            end
        end
    end

    scan_views(views_path)

    -- Also scan Inertia page components
    local inertia_dirs = {
        root .. '/resources/js/Pages',
        root .. '/resources/js/pages', -- lowercase variant
    }

    for _, inertia_dir in ipairs(inertia_dirs) do
        if vim.fn.isdirectory(inertia_dir) == 1 then
            local function scan_inertia(dir, prefix)
                prefix = prefix or ''
                local items = vim.fn.readdir(dir) or {}

                for _, item in ipairs(items) do
                    local full_path = dir .. '/' .. item
                    local component_name = prefix .. (prefix ~= '' and '.' or '') .. item

                    if vim.fn.isdirectory(full_path) == 1 then
                        scan_inertia(full_path, component_name)
                    elseif item:match('%.[jt]sx?$') or item:match('%.vue$') or item:match('%.svelte$') then
                        -- Remove file extension for component name
                        component_name = component_name:gsub('%.[^.]+$', '')
                        view_names[#view_names + 1] = component_name
                    end
                end
            end

            scan_inertia(inertia_dir)
        end
    end

    table.sort(view_names)

    cache.views.data = view_names
    cache.views.timestamp = os.time()
    return view_names
end

-- Extract config keys from config files
local function get_config_keys()
    if is_cache_valid(cache.config) then
        return cache.config.data
    end

    local root = get_project_root()
    if not root then return {} end

    local config_path = root .. '/config'
    if vim.fn.isdirectory(config_path) == 0 then
        cache.config.data = {}
        cache.config.timestamp = os.time()
        return {}
    end

    local config_keys = {}
    local config_files = vim.fn.glob(config_path .. '/*.php', false, true)

    for _, config_file in ipairs(config_files) do
        local filename = vim.fn.fnamemodify(config_file, ':t:r') -- Get filename without extension

        -- Add basic file-level keys
        config_keys[#config_keys + 1] = filename

        -- Try to extract array keys from the config file
        if vim.fn.filereadable(config_file) == 1 then
            local lines = vim.fn.readfile(config_file)
            for _, line in ipairs(lines) do
                -- Match 'key' => patterns in config arrays
                local key = line:match("['\"]([^'\"]+)['\"]%s*=>")
                if key and not key:match('^%d+$') then -- Skip numeric keys
                    config_keys[#config_keys + 1] = filename .. '.' .. key
                end
            end
        end
    end

    -- Remove duplicates and sort
    local unique_keys = {}
    local seen = {}
    for _, key in ipairs(config_keys) do
        if not seen[key] then
            seen[key] = true
            unique_keys[#unique_keys + 1] = key
        end
    end
    table.sort(unique_keys)

    cache.config.data = unique_keys
    cache.config.timestamp = os.time()
    return unique_keys
end

-- Extract translation keys from lang files
local function get_translation_keys()
    if is_cache_valid(cache.translations) then
        return cache.translations.data
    end

    local root = get_project_root()
    if not root then return {} end

    local lang_paths = {
        root .. '/resources/lang',
        root .. '/lang' -- Laravel 9+ structure
    }

    local translation_keys = {}

    for _, lang_path in ipairs(lang_paths) do
        if vim.fn.isdirectory(lang_path) == 1 then
            -- Scan language directories (en, es, etc.)
            local lang_dirs = vim.fn.readdir(lang_path) or {}
            for _, lang_dir in ipairs(lang_dirs) do
                local full_lang_path = lang_path .. '/' .. lang_dir
                if vim.fn.isdirectory(full_lang_path) == 1 then
                    -- Scan PHP files in language directory
                    local lang_files = vim.fn.glob(full_lang_path .. '/*.php', false, true)
                    for _, lang_file in ipairs(lang_files) do
                        local filename = vim.fn.fnamemodify(lang_file, ':t:r')

                        -- Add file-level key
                        translation_keys[#translation_keys + 1] = filename

                        -- Extract array keys
                        if vim.fn.filereadable(lang_file) == 1 then
                            local lines = vim.fn.readfile(lang_file)
                            for _, line in ipairs(lines) do
                                local key = line:match("['\"]([^'\"]+)['\"]%s*=>")
                                if key and not key:match('^%d+$') then
                                    translation_keys[#translation_keys + 1] = filename .. '.' .. key
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- Remove duplicates and sort
    local unique_keys = {}
    local seen = {}
    for _, key in ipairs(translation_keys) do
        if not seen[key] then
            seen[key] = true
            unique_keys[#unique_keys + 1] = key
        end
    end
    table.sort(unique_keys)

    cache.translations.data = unique_keys
    cache.translations.timestamp = os.time()
    return unique_keys
end

-- Extract environment variables from .env files
local function get_env_keys()
    if is_cache_valid(cache.env) then
        return cache.env.data
    end

    local root = get_project_root()
    if not root then return {} end

    local env_keys = {}
    local env_files = {
        root .. '/.env',
        root .. '/.env.example',
        root .. '/.env.local',
        root .. '/.env.production',
        root .. '/.env.staging',
        root .. '/.env.testing',
    }

    for _, env_file in ipairs(env_files) do
        if vim.fn.filereadable(env_file) == 1 then
            local lines = vim.fn.readfile(env_file)
            for _, line in ipairs(lines) do
                -- Skip comments and empty lines
                if not line:match('^%s*#') and not line:match('^%s*$') then
                    -- Match KEY=value patterns
                    local key = line:match('^([A-Z_][A-Z0-9_]*)%s*=')
                    if key then
                        env_keys[#env_keys + 1] = key
                    end
                end
            end
        end
    end

    -- Remove duplicates and sort
    local unique_keys = {}
    local seen = {}
    for _, key in ipairs(env_keys) do
        if not seen[key] then
            seen[key] = true
            unique_keys[#unique_keys + 1] = key
        end
    end
    table.sort(unique_keys)

    cache.env.data = unique_keys
    cache.env.timestamp = os.time()
    return unique_keys
end

-- Get Livewire component names for completions
local function get_livewire_components()
    if is_cache_valid(cache.livewire) then
        return cache.livewire.data
    end

    local components = livewire.find_livewire_components()
    local component_names = {}

    for _, component in ipairs(components) do
        table.insert(component_names, component.name)
        -- Also add class name for alternative completion
        if component.class_name ~= component.name then
            table.insert(component_names, component.class_name)
        end
    end

    table.sort(component_names)

    cache.livewire.data = component_names
    cache.livewire.timestamp = os.time()
    return component_names
end

-- Get wire directives for completions
local function get_wire_directives()
    if is_cache_valid(cache.wire_directives) then
        return cache.wire_directives.data
    end

    local directives = livewire.get_wire_directives()

    cache.wire_directives.data = directives
    cache.wire_directives.timestamp = os.time()
    return directives
end

-- Get Livewire component properties and methods for completions
local function get_livewire_properties(component_name)
    local root = get_project_root()
    if not root or not component_name then return {} end

    local components = livewire.find_livewire_components()
    local target_component = nil

    for _, component in ipairs(components) do
        if component.name == component_name then
            target_component = component
            break
        end
    end

    if not target_component or not target_component.path then
        return {}
    end

    local properties = {}

    if vim.fn.filereadable(target_component.path) == 1 then
        local lines = vim.fn.readfile(target_component.path)

        for _, line in ipairs(lines) do
            -- Match public properties
            local prop = line:match('public%s+%$([%w_]+)')
            if prop then
                table.insert(properties, prop)
            end

            -- Match public methods
            local method = line:match('public%s+function%s+([%w_]+)%s*%(')
            if method and method ~= '__construct' and method ~= 'render' then
                table.insert(properties, method .. '()')
            end

            -- Match #[Computed] properties
            if line:match('#%[Computed%]') then
                -- Look at next line for method name
                local next_idx = _
                if lines[next_idx + 1] then
                    local computed = lines[next_idx + 1]:match('public%s+function%s+([%w_]+)%s*%(')
                    if computed then
                        table.insert(properties, computed)
                    end
                end
            end
        end
    end

    return properties
end

-- Get completions based on function context
function M.get_completions(func_name, partial)
    partial = partial or ''

    local completions = {}

    if func_name == 'route' then
        completions = get_route_names()
    elseif func_name == 'view' then
        completions = get_view_names()
    elseif func_name == 'config' then
        completions = get_config_keys()
    elseif func_name == '__' or func_name == 'trans' then
        completions = get_translation_keys()
    elseif func_name == 'env' then
        completions = get_env_keys()

        -- Livewire completions
    elseif func_name == 'livewire' or func_name == '@livewire' then
        completions = get_livewire_components()
    elseif func_name == 'wire' then
        completions = get_wire_directives()
    elseif func_name == '$wire' then
        -- Get properties/methods from current component context
        local current_file = vim.fn.expand('%:p')
        local component_name = nil

        -- Try to determine current component from file path
        if current_file:match('/resources/views/livewire/') then
            -- Extract component name from view path
            local view_name = current_file:match('/resources/views/livewire/(.+)%.blade%.php$')
            if view_name then
                component_name = view_name:gsub('/', '.')
            end
        end

        if component_name then
            completions = get_livewire_properties(component_name)
        end
    elseif func_name == 'app' then
        -- Use IDE helper for container bindings
        local ok, ide_helper = pcall(require, 'laravel.ide_helper')
        if ok then
            completions = ide_helper.get_container_completions()
        end
    elseif func_name == 'facade' then
        -- Use IDE helper for facade method completions
        local ok, ide_helper = pcall(require, 'laravel.ide_helper')
        if ok then
            completions = ide_helper.get_facade_completions(partial)
        end
    elseif func_name == 'fluent' then
        -- Use IDE helper for fluent method completions
        local ok, ide_helper = pcall(require, 'laravel.ide_helper')
        if ok then
            completions = ide_helper.get_fluent_completions()
        end
    end

    -- Filter by partial match if provided (except for facade which already filters)
    if partial ~= '' and func_name ~= 'facade' then
        local filtered = {}
        local partial_lower = partial:lower()
        for _, completion in ipairs(completions) do
            if completion:lower():find(partial_lower, 1, true) then
                filtered[#filtered + 1] = completion
            end
        end
        return filtered
    end

    return completions
end

-- Get context-aware completions for Blade templates
function M.get_blade_completions()
    local line = vim.fn.getline('.')
    local col = vim.fn.col('.') - 1

    -- Check for Livewire directive context
    if line:sub(1, col):match('@livewire%s*%($') or
        line:sub(1, col):match('@livewire%s*%([\'"]$') then
        return get_livewire_components()
    end

    -- Check for wire: attribute context
    if line:sub(1, col):match('wire:$') then
        return get_wire_directives()
    end

    -- Check for Livewire tag context
    if line:sub(1, col):match('<livewire:$') then
        return get_livewire_components()
    end

    -- Check for Alpine.js $wire context
    if line:sub(1, col):match('%$wire%.$') then
        -- Get current component context and return its properties
        local current_file = vim.fn.expand('%:p')
        if current_file:match('/resources/views/livewire/') then
            local view_name = current_file:match('/resources/views/livewire/(.+)%.blade%.php$')
            if view_name then
                local component_name = view_name:gsub('/', '.')
                return get_livewire_properties(component_name)
            end
        end
    end

    return {}
end

-- Clear all caches
function M.clear_cache()
    for key, _ in pairs(cache) do
        cache[key] = { data = {}, timestamp = 0 }
    end
end

-- Setup completion sources
function M.setup()
    -- We'll integrate with completion engines in the setup
    -- For now, just ensure caches are initialized
    vim.api.nvim_create_autocmd('BufWritePost', {
        pattern = { '*/app/Livewire/*.php', '*/app/Http/Livewire/*.php', '*/resources/views/livewire/*.blade.php' },
        callback = function()
            cache.livewire = { data = {}, timestamp = 0 }
            cache.wire_directives = { data = {}, timestamp = 0 }
        end
    })
end

return M
