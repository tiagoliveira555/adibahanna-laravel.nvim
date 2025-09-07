-- Laravel Livewire 3 integration module
local M = {}
local ui = require('laravel.ui')

local function get_project_root()
    return _G.laravel_nvim.project_root
end

-- Detect Livewire components
function M.find_livewire_components()
    local root = get_project_root()
    if not root then return {} end

    local components, seen = {}, {}
    local search_paths = {
        { path = root .. '/app/Livewire',      namespace = 'App\\Livewire' },
        { path = root .. '/app/Http/Livewire', namespace = 'App\\Http\\Livewire' },
    }

    local function scan_directory(dir, namespace)
        if vim.fn.isdirectory(dir) ~= 1 then return end
        local items = vim.fn.readdir(dir) or {}

        for _, item in ipairs(items) do
            local full_path = dir .. '/' .. item
            if vim.fn.isdirectory(full_path) == 1 then
                scan_directory(full_path, namespace .. '\\' .. item)
            elseif item:match('%.php$') and not item:match('Test%.php$') then
                local class_name = item:gsub('%.php$', '')
                local full_class = namespace .. '\\' .. class_name
                local component_name = M.namespace_to_component_name(full_class)
                if not seen[component_name] then
                    seen[component_name] = true
                    table.insert(components, {
                        name = component_name,
                        class_name = class_name,
                        namespace = full_class,
                        path = full_path,
                        view_path = M.get_component_view_path(component_name, full_path),
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
    local name = namespace:gsub('^App\\Http\\Livewire\\', ''):gsub('^App\\Livewire\\', '')
    name = name:gsub('\\', '.')
    name = name:gsub('([a-z])([A-Z])', '%1-%2')
    return name:lower()
end

-- Resolve component view path
function M.get_component_view_path(component_name, class_path)
    local root = get_project_root()
    if not root then return nil end

    if class_path and vim.fn.filereadable(class_path) == 1 then
        local content = table.concat(vim.fn.readfile(class_path), '\n')
        if content:match('function%s+render%s*%(') and content:match('view%s*%(') then
            local view_name = content:match("view%s*%(%s*['\"]([^'\"]+)['\"]")
            if view_name then return M.resolve_view_path(view_name) end
        end
    end

    local view_name = 'livewire.' .. component_name:gsub('%.', '.')
    return M.resolve_view_path(view_name)
end

-- Resolve view path from name
function M.resolve_view_path(view_name)
    local root = get_project_root()
    if not root then return nil end
    local view_path = root .. '/resources/views/' .. view_name:gsub('%.', '/') .. '.blade.php'
    return vim.fn.filereadable(view_path) == 1 and view_path or nil
end

-- Navigate to Livewire component class
function M.goto_livewire_component(component_name)
    if not component_name or component_name == '' then return end
    local components = M.find_livewire_components()
    for _, c in ipairs(components) do
        if c.name == component_name or c.name:match(component_name) or c.class_name:lower():match(component_name:lower()) then
            vim.cmd('edit ' .. c.path)
            return
        end
    end
    ui.error('Livewire component not found: ' .. component_name)
end

-- Navigate to Livewire component view
function M.goto_livewire_view(component_name)
    if not component_name then return end
    local components = M.find_livewire_components()
    for _, c in ipairs(components) do
        if c.name == component_name then
            if c.view_path then
                vim.cmd('edit ' .. c.view_path)
                return
            end
        end
    end

    local view_path = M.resolve_view_path('livewire.' .. component_name:gsub('%-', '.'))
    if view_path then
        vim.cmd('edit ' .. view_path)
        return
    end
    ui.warn('Livewire view not found: ' .. component_name)
end

-- Check if current line is Livewire-related
-- Check if cursor is in a Livewire context
function M.is_livewire_context()
    local line = vim.fn.getline('.')

    -- PHP: return view('livewire.something')
    if line:match("view%s*%(%s*['\"]livewire[%.%-][^'\"]+['\"]") then
        return true
    end

    -- Blade: <livewire:component-name />
    if line:match("<livewire:([%w%-%.]+)") then
        return true
    end

    -- Blade/Directive: @livewire('component-name')
    if line:match("@livewire%s*%(%s*['\"][^'\"]+['\"]") then
        return true
    end

    -- Existing patterns (wire:, $wire, etc.)
    local php_patterns = {
        'Livewire::',
        '@livewireScripts',
        '@livewireStyles',
        '<livewire:',
        'wire:',
        '%$wire',
        '@entangle%s*%(',
        '%$dispatch%s*%(',
        '%$set%s*%(',
        '%$toggle%s*%(',
        '%$emit%s*%(',
    }

    for _, pattern in ipairs(php_patterns) do
        if line:match(pattern) then
            return true
        end
    end

    return false
end

-- Go to Livewire class or view depending on context
function M.goto_livewire_definition()
    local line = vim.fn.getline('.')

    -- @livewire('component')
    local component = line:match("@livewire%s*%(%s*['\"]([^'\"]+)['\"]")
    if component then
        M.goto_livewire_component(component)
        return true
    end

    -- <livewire:component>
    component = line:match("<livewire:([%w%-%.]+)")
    if component then
        M.goto_livewire_component(component)
        return true
    end

    -- Livewire::component('name', ...)
    component = line:match("Livewire::component%s*%(%s*['\"]([^'\"]+)['\"]")
    if component then
        M.goto_livewire_component(component)
        return true
    end

    -- view('livewire.xxx')
    component = line:match("view%s*%(%s*['\"]livewire%.([^'\"]+)['\"]")
    if component then
        -- Try to open view first
        local view_path = M.resolve_view_path('livewire.' .. component)
        if view_path then
            vim.cmd('edit ' .. view_path)
        else
            -- Fallback to class
            M.goto_livewire_component(component)
        end
        return true
    end

    return false
end

function M.setup()
    -- placeholder for future integration if needed
end

return M
