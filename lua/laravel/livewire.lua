-- Laravel Livewire 3 Integration Module
-- Handles navigation between Livewire components and views in Laravel projects
local M = {}

local ui = require('laravel.ui')

-- Get Laravel project root
local function get_project_root()
    return _G.laravel_nvim and _G.laravel_nvim.project_root
end

-- Convert namespace to kebab-case Livewire component name
function M.namespace_to_component_name(namespace)
    local name = namespace:gsub('^App\\Http\\Livewire\\', ''):gsub('^App\\Livewire\\', '')
    name = name:gsub('\\', '.')
    name = name:gsub('([a-z])([A-Z])', '%1-%2')
    return name:lower()
end

-- Resolve Blade view path from view name
function M.resolve_view_path(view_name)
    local root = get_project_root()
    if not root then return nil end
    local path = root .. '/resources/views/' .. view_name:gsub('%.', '/') .. '.blade.php'
    return vim.fn.filereadable(path) == 1 and path or nil
end

-- Detect Livewire components in default directories
function M.find_livewire_components()
    local root = get_project_root()
    if not root then return {} end

    local components, seen = {}, {}
    local search_paths = {
        { path = root .. '/app/Livewire',      namespace = 'App\\Livewire' },
        { path = root .. '/app/Http/Livewire', namespace = 'App\\Http\\Livewire' },
    }

    local function scan(dir, namespace)
        if vim.fn.isdirectory(dir) ~= 1 then return end
        for _, item in ipairs(vim.fn.readdir(dir)) do
            local full_path = dir .. '/' .. item
            if vim.fn.isdirectory(full_path) == 1 then
                scan(full_path, namespace .. '\\' .. item)
            elseif item:match('%.php$') and not item:match('Test%.php$') then
                local class_name = item:gsub('%.php$', '')
                local full_class = namespace .. '\\' .. class_name
                local name = M.namespace_to_component_name(full_class)
                if not seen[name] then
                    seen[name] = true
                    table.insert(components, {
                        name = name,
                        class_name = class_name,
                        namespace = full_class,
                        path = full_path,
                        view_path = M.get_component_view_path(name, full_path)
                    })
                end
            end
        end
    end

    for _, search in ipairs(search_paths) do
        scan(search.path, search.namespace)
    end

    return components
end

-- Get the view path associated with a component class
function M.get_component_view_path(component_name, class_path)
    -- Attempt to extract from render() method
    if class_path and vim.fn.filereadable(class_path) == 1 then
        local content = table.concat(vim.fn.readfile(class_path), '\n')
        local view_name = content:match("view%s*%(%s*['\"]([^'\"]+)['\"]")
        if view_name then
            return M.resolve_view_path(view_name)
        end
    end
    -- Default view path for Livewire 3
    return M.resolve_view_path('livewire.' .. component_name:gsub('%.', '.'))
end

-- Navigate to a Livewire component class by name
function M.goto_livewire_component(name)
    if not name or name == '' then
        local components = M.find_livewire_components()
        if #components == 0 then
            ui.warn('No Livewire components found')
            return
        end
        local items = {}
        for _, c in ipairs(components) do table.insert(items, c.name) end
        ui.select(items, { prompt = 'Select Livewire component:', kind = 'livewire_component' }, function(choice)
            if choice then
                for _, c in ipairs(components) do
                    if c.name == choice then
                        vim.cmd('edit ' .. c.path)
                        break
                    end
                end
            end
        end)
        return
    end

    for _, c in ipairs(M.find_livewire_components()) do
        if c.name == name or c.class_name:lower():match(name:lower()) then
            vim.cmd('edit ' .. c.path)
            return
        end
    end

    ui.error('Livewire component not found: ' .. name)
end

-- Navigate to a Livewire view by component name
function M.goto_livewire_view(name)
    if not name then return ui.warn('No component name provided') end

    for _, c in ipairs(M.find_livewire_components()) do
        if c.name == name and c.view_path then
            vim.cmd('edit ' .. c.view_path)
            return
        end
    end

    local view_path = M.resolve_view_path('livewire.' .. name:gsub('%-', '.'))
    if view_path then
        vim.cmd('edit ' .. view_path)
    else
        ui.warn('Livewire view not found: ' .. name)
    end
end

-- Toggle between component class and view
function M.toggle_livewire_file()
    local file = vim.fn.expand('%:p')
    local root = get_project_root()
    if not root then return ui.error('Not in a Laravel project') end

    if file:match('/app/.*/Livewire/.*%.php$') then
        local class_name = vim.fn.expand('%:t:r')
        for _, c in ipairs(M.find_livewire_components()) do
            if c.class_name == class_name and c.view_path then
                vim.cmd('edit ' .. c.view_path)
                return
            end
        end
        ui.warn('Could not find view for component: ' .. class_name)
    elseif file:match('/resources/views/livewire/.*%.blade%.php$') then
        local comp_name = file:gsub(root .. '/resources/views/livewire/', ''):gsub('%.blade%.php$', ''):gsub('/', '.')
        for _, c in ipairs(M.find_livewire_components()) do
            if c.name == comp_name then
                vim.cmd('edit ' .. c.path)
                return
            end
        end
        ui.warn('Could not find component class for view')
    else
        ui.info('Not in a Livewire component or view file')
    end
end

-- Check if cursor is inside a Livewire context
function M.is_livewire_context()
    local line = vim.fn.getline('.')
    local patterns = {
        'Livewire::', '@livewire%s*%(', '<livewire:', 'wire:', '$wire', '@entangle%s*%(',
        '$dispatch%s*%(', '$refresh', '$set%s*%(', '$toggle%s*%(', '$emit%s*%(', '$emitUp%s*%(', '$emitSelf%s*%(',
        '$emitTo%s*%('
    }
    for _, p in ipairs(patterns) do
        if line:match(p) then return true end
    end
    return false
end

-- Navigate to Livewire definition based on cursor context
function M.goto_livewire_definition()
    local line = vim.fn.getline('.')
    local component = line:match("@livewire%s*%(%s*['\"]([^'\"]+)['\"]")
        or line:match("<livewire:([%w%-%.]+)")
        or line:match("Livewire::component%s*%(%s*['\"]([^'\"]+)['\"]")
    if component then
        M.goto_livewire_component(component)
        return true
    end
    return false
end

-- Setup integration (optional for Treesitter/Laravel integration)
function M.setup()
    local ts_utils = require('laravel.navigate').ts_utils
    if ts_utils then
        local original_create = ts_utils.create_laravel_call_info
        ts_utils.create_laravel_call_info = function(function_name, scope_name, method_name, string_args, call_type)
            if scope_name == 'Livewire' and method_name == 'component' then
                return { func = 'livewire_component', partial = string_args[1], call_type = call_type, function_name =
                function_name }
            end
            return original_create(function_name, scope_name, method_name, string_args, call_type)
        end
    end
end

return M
