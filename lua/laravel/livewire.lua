-- Laravel Livewire 3 integration module
local M = {}

local ui = require('laravel.ui')

-- Get Laravel project root
local function get_project_root()
    return _G.laravel_nvim.project_root
end

-- Find Livewire components
function M.find_livewire_components()
    local root = get_project_root()
    if not root then return {} end

    local components = {}
    local seen = {}

    -- Livewire 3 default locations
    local search_paths = {
        { path = root .. '/app/Livewire',      namespace = 'App\\Livewire' },
        { path = root .. '/app/Http/Livewire', namespace = 'App\\Http\\Livewire' },
        -- Custom paths from config/livewire.php if needed
    }

    local function scan_directory(dir, namespace)
        if vim.fn.isdirectory(dir) ~= 1 then
            return
        end

        local items = vim.fn.readdir(dir) or {}

        for _, item in ipairs(items) do
            local full_path = dir .. '/' .. item

            if vim.fn.isdirectory(full_path) == 1 then
                -- Recursively scan subdirectories
                scan_directory(full_path, namespace .. '\\' .. item)
            elseif item:match('%.php$') and not item:match('Test%.php$') then
                local class_name = item:gsub('%.php$', '')
                local full_class = namespace .. '\\' .. class_name

                -- Convert namespace to component name (kebab-case)
                local component_name = M.namespace_to_component_name(full_class)

                if not seen[component_name] then
                    seen[component_name] = true
                    table.insert(components, {
                        name = component_name,
                        class_name = class_name,
                        namespace = full_class,
                        path = full_path,
                        view_path = M.get_component_view_path(component_name, full_path)
                    })
                end
            end
        end
    end

    for _, search in ipairs(search_paths) do
        scan_directory(search.path, search.namespace)
    end

    return components
end

-- Convert namespace to Livewire component name
function M.namespace_to_component_name(namespace)
    -- Remove App\Livewire or App\Http\Livewire prefix
    local name = namespace:gsub('^App\\Http\\Livewire\\', '')
    name = name:gsub('^App\\Livewire\\', '')

    -- Convert to kebab-case
    name = name:gsub('\\', '.')
    name = name:gsub('([a-z])([A-Z])', '%1-%2')
    name = name:lower()

    return name
end

-- Get component view path
function M.get_component_view_path(component_name, class_path)
    local root = get_project_root()
    if not root then return nil end

    -- Check if component uses inline template
    if class_path and vim.fn.filereadable(class_path) == 1 then
        local content = table.concat(vim.fn.readfile(class_path), '\n')
        if content:match('function%s+render%s*%(') and content:match('view%s*%(') then
            -- Has render method with view
            local view_name = content:match("view%s*%(%s*['\"]([^'\"]+)['\"]")
            if view_name then
                return M.resolve_view_path(view_name)
            end
        end
    end

    -- Default view path for Livewire 3
    local view_name = 'livewire.' .. component_name:gsub('%.', '.')
    return M.resolve_view_path(view_name)
end

-- Resolve view path from view name
function M.resolve_view_path(view_name)
    local root = get_project_root()
    if not root then return nil end

    local view_path = root .. '/resources/views/' .. view_name:gsub('%.', '/') .. '.blade.php'

    if vim.fn.filereadable(view_path) == 1 then
        return view_path
    end

    return nil
end

-- Navigate to Livewire component
function M.goto_livewire_component(component_name)
    if not component_name or component_name == '' then
        -- Show component picker
        local components = M.find_livewire_components()
        if #components == 0 then
            ui.warn('No Livewire components found')
            return
        end

        local items = {}
        for _, component in ipairs(components) do
            table.insert(items, component.name)
        end

        ui.select(items, {
            prompt = 'Select Livewire component:',
            kind = 'livewire_component',
        }, function(choice)
            if choice then
                for _, component in ipairs(components) do
                    if component.name == choice then
                        vim.cmd('edit ' .. component.path)
                        break
                    end
                end
            end
        end)
    else
        -- Find specific component
        local components = M.find_livewire_components()

        for _, component in ipairs(components) do
            if component.name == component_name or
                component.name:match(component_name) or
                component.class_name:lower():match(component_name:lower()) then
                vim.cmd('edit ' .. component.path)
                return
            end
        end

        ui.error('Livewire component not found: ' .. component_name)
    end
end

-- Navigate to Livewire view
function M.goto_livewire_view(component_name)
    if not component_name then
        ui.warn('No component name provided')
        return
    end

    local components = M.find_livewire_components()

    for _, component in ipairs(components) do
        if component.name == component_name then
            if component.view_path then
                vim.cmd('edit ' .. component.view_path)
            else
                ui.warn('View file not found for component: ' .. component_name)
            end
            return
        end
    end

    -- Try to find view directly
    local view_name = 'livewire.' .. component_name:gsub('%-', '.')
    local view_path = M.resolve_view_path(view_name)

    if view_path then
        vim.cmd('edit ' .. view_path)
    else
        ui.warn('Livewire view not found: ' .. view_name)
    end
end

-- Toggle between Livewire component class and view
function M.toggle_livewire_file()
    local current_file = vim.fn.expand('%:p')
    local root = get_project_root()

    if not root then
        ui.error('Not in a Laravel project')
        return
    end

    -- Check if in Livewire class file
    if current_file:match('/app/.*Livewire/.*%.php$') or
        current_file:match('/app/Livewire/.*%.php$') then
        -- In component class, go to view
        local class_name = vim.fn.expand('%:t:r')
        local components = M.find_livewire_components()

        for _, component in ipairs(components) do
            if component.class_name == class_name and component.view_path then
                vim.cmd('edit ' .. component.view_path)
                return
            end
        end

        ui.warn('Could not find view for component: ' .. class_name)

        -- Check if in Livewire view file
    elseif current_file:match('/resources/views/livewire/.*%.blade%.php$') then
        -- In view, go to component class
        local view_path = current_file:gsub(root .. '/resources/views/', ''):gsub('%.blade%.php$', '')
        local component_name = view_path:gsub('/', '.'):gsub('livewire%.', '')

        local components = M.find_livewire_components()

        for _, component in ipairs(components) do
            if component.name == component_name or
                component.name:gsub('%-', '.') == component_name then
                vim.cmd('edit ' .. component.path)
                return
            end
        end

        ui.warn('Could not find component class for view')
    else
        ui.info('Not in a Livewire component or view file')
    end
end

-- Get Livewire component completions
function M.get_livewire_completions()
    local components = M.find_livewire_components()
    local completions = {}

    for _, component in ipairs(components) do
        table.insert(completions, component.name)
    end

    return completions
end

-- Extract Livewire wire directives from current file
function M.get_wire_directives()
    local directives = {
        -- Events
        'wire:click',
        'wire:submit',
        'wire:keydown',
        'wire:keyup',
        'wire:mouseenter',
        'wire:mouseleave',
        'wire:focus',
        'wire:blur',
        'wire:change',

        -- Modifiers
        'wire:click.prevent',
        'wire:click.stop',
        'wire:click.self',
        'wire:submit.prevent',
        'wire:keydown.enter',
        'wire:keydown.escape',
        'wire:keydown.tab',
        'wire:keydown.arrow-up',
        'wire:keydown.arrow-down',

        -- Model binding
        'wire:model',
        'wire:model.live',
        'wire:model.blur',
        'wire:model.change',
        'wire:model.defer',
        'wire:model.lazy',
        'wire:model.debounce',
        'wire:model.throttle',
        'wire:model.fill',

        -- Loading states
        'wire:loading',
        'wire:loading.remove',
        'wire:loading.attr',
        'wire:loading.class',
        'wire:loading.class.remove',
        'wire:target',

        -- Polling
        'wire:poll',
        'wire:poll.750ms',
        'wire:poll.1s',
        'wire:poll.2s',
        'wire:poll.5s',
        'wire:poll.10s',
        'wire:poll.15s',
        'wire:poll.30s',
        'wire:poll.60s',
        'wire:poll.keep-alive',
        'wire:poll.visible',

        -- Other
        'wire:init',
        'wire:ignore',
        'wire:ignore.self',
        'wire:key',
        'wire:dirty',
        'wire:offline',
        'wire:transition',
    }

    return directives
end

-- Check if cursor is in a Livewire context
function M.is_livewire_context()
    local line = vim.fn.getline('.')

    -- Check for Livewire PHP contexts
    local php_patterns = {
        'Livewire::',
        '@livewire%s*%(',
        '@livewireScripts',
        '@livewireStyles',
        '<livewire:',
        'wire:',
        '$wire',
        '@entangle%s*%(',
        '$dispatch%s*%(',
        '$refresh',
        '$set%s*%(',
        '$toggle%s*%(',
        '$emit%s*%(',
        '$emitUp%s*%(',
        '$emitSelf%s*%(',
        '$emitTo%s*%(',
    }

    for _, pattern in ipairs(php_patterns) do
        if line:match(pattern) then
            return true
        end
    end

    -- Check for Alpine.js + Livewire contexts
    local alpine_patterns = {
        '%$wire%.',
        '@entangle%s*%(',
        '%$dispatch%s*%(',
    }

    for _, pattern in ipairs(alpine_patterns) do
        if line:match(pattern) then
            return true
        end
    end

    return false
end

-- Navigate based on Livewire context
function M.goto_livewire_definition()
    local line = vim.fn.getline('.')
    local col = vim.fn.col('.')

    -- Extract Livewire component from @livewire directive
    local component = line:match("@livewire%s*%(%s*['\"]([^'\"]+)['\"]")
    if component then
        M.goto_livewire_component(component)
        return true
    end

    -- Extract component from <livewire: tag
    component = line:match("<livewire:([%w%-%.]+)")
    if component then
        M.goto_livewire_component(component)
        return true
    end

    -- Extract component from Livewire::component
    component = line:match("Livewire::component%s*%(%s*['\"]([^'\"]+)['\"]")
    if component then
        M.goto_livewire_component(component)
        return true
    end

    return false
end

-- Setup Livewire integration
function M.setup()
    -- Add to existing treesitter patterns
    local ts_utils = require('laravel.navigate').ts_utils
    if ts_utils then
        -- Extend Laravel functions mapping
        local original_create = ts_utils.create_laravel_call_info
        ts_utils.create_laravel_call_info = function(function_name, scope_name, method_name, string_args, call_type)
            -- Check for Livewire-specific calls
            if scope_name == 'Livewire' then
                if method_name == 'component' then
                    return {
                        func = 'livewire_component',
                        partial = string_args[1],
                        call_type = call_type,
                        function_name = function_name,
                        scope_name = scope_name,
                        method_name = method_name,
                        all_args = string_args
                    }
                end
            end

            -- Fall back to original implementation
            return original_create(function_name, scope_name, method_name, string_args, call_type)
        end
    end
end

return M
