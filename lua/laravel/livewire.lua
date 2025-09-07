-- Laravel Livewire 3 integration module
local M = {}

local ui = require('laravel.ui')

-- Get Laravel project root
local function get_project_root()
    return _G.laravel_nvim.project_root
end

-- =========================================================
-- Helpers for components and views
-- =========================================================

-- Convert namespace to Livewire component name (kebab-case)
function M.namespace_to_component_name(namespace)
    local name = namespace:gsub('^App\\Http\\Livewire\\', '')
    name = name:gsub('^App\\Livewire\\', '')
    name = name:gsub('\\', '.')
    name = name:gsub('([a-z])([A-Z])', '%1-%2')
    name = name:lower()
    return name
end

-- Resolve view path from view name (ex: "livewire.contact-page")
function M.resolve_view_path(view_name)
    local root = get_project_root()
    if not root then return nil end

    local view_path = root .. '/resources/views/' .. view_name:gsub('%.', '/') .. '.blade.php'
    if vim.fn.filereadable(view_path) == 1 then
        return view_path
    end
    return nil
end

-- Get component view path (tries render() override first, fallback to default convention)
function M.get_component_view_path(component_name, class_path)
    local root = get_project_root()
    if not root then return nil end

    -- Inspect render() method if class exists
    if class_path and vim.fn.filereadable(class_path) == 1 then
        local content = table.concat(vim.fn.readfile(class_path), '\n')
        local view_name = content:match("view%s*%(%s*['\"]([^'\"]+)['\"]")
        if view_name then
            return M.resolve_view_path(view_name)
        end
    end

    -- Default Livewire 3 view path
    local view_name = 'livewire.' .. component_name:gsub('%.', '.')
    return M.resolve_view_path(view_name)
end

-- =========================================================
-- Core Livewire navigation
-- =========================================================

-- Check if cursor is in a Livewire-related context
function M.is_livewire_context()
    local line = vim.fn.getline('.')

    -- return view('livewire.xxx')
    if line:match("view%s*%(%s*['\"]livewire[%.%-][^'\"]+['\"]") then
        return true
    end

    -- <livewire:xxx />
    if line:match("<livewire:([%w%-%.]+)") then
        return true
    end

    -- @livewire('xxx')
    if line:match("@livewire%s*%(%s*['\"][^'\"]+['\"]") then
        return true
    end

    -- Other Livewire patterns
    local php_patterns = {
        'Livewire::',
        '@livewireScripts',
        '@livewireStyles',
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

-- Go to definition depending on Livewire context
function M.goto_livewire_definition()
    local line = vim.fn.getline('.')
    print("DEBUG line: " .. line)

    -- @livewire('component')
    local component = line:match("@livewire%s*%(%s*['\"]([^'\"]+)['\"]")
    if component then
        print("DEBUG matched @livewire: " .. component)
        M.goto_livewire_component(component)
        return true
    end

    -- <livewire:component />
    component = line:match("<livewire:([%w%-%.]+)")
    if component then
        print("DEBUG matched <livewire:>: " .. component)
        M.goto_livewire_component(component)
        return true
    end

    -- Livewire::component('name', Class::class)
    component = line:match("Livewire::component%s*%(%s*['\"]([^'\"]+)['\"]")
    if component then
        print("DEBUG matched Livewire::component: " .. component)
        M.goto_livewire_component(component)
        return true
    end

    -- return view('livewire.xxx')
    local view = line:match("view%s*%(%s*['\"](livewire[%.%-][^'\"]+)['\"]")
    if view then
        print("DEBUG matched view: " .. view)
        local path = M.resolve_view_path(view)
        if path then
            print("DEBUG resolved view path: " .. path)
            vim.cmd("edit " .. path)
            return true
        else
            print("DEBUG could not resolve view path for: " .. view)
        end
    end

    print("DEBUG no match found")
    return false
end
-- =========================================================
-- Component & View Navigation
-- =========================================================

-- Find all Livewire components
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

-- Open Livewire component class file
function M.goto_livewire_component(component_name)
    local components = M.find_livewire_components()

    for _, component in ipairs(components) do
        if component.name == component_name
            or component.name:match(component_name)
            or component.class_name:lower():match(component_name:lower()) then
            vim.cmd('edit ' .. component.path)
            return
        end
    end

    ui.error('Livewire component not found: ' .. component_name)
end

-- Toggle between component class and view
function M.toggle_livewire_file()
    local current_file = vim.fn.expand('%:p')
    local root = get_project_root()
    if not root then
        ui.error('Not in a Laravel project')
        return
    end

    if current_file:match('/app/.*/Livewire/.*%.php$') then
        local class_name = vim.fn.expand('%:t:r')
        local components = M.find_livewire_components()
        for _, component in ipairs(components) do
            if component.class_name == class_name and component.view_path then
                vim.cmd('edit ' .. component.view_path)
                return
            end
        end
        ui.warn('Could not find view for component: ' .. class_name)
    elseif current_file:match('/resources/views/livewire/.*%.blade%.php$') then
        local view_path = current_file:gsub(root .. '/resources/views/', ''):gsub('%.blade%.php$', '')
        local component_name = view_path:gsub('/', '.'):gsub('livewire%.', '')
        local components = M.find_livewire_components()
        for _, component in ipairs(components) do
            if component.name == component_name or component.name:gsub('%-', '.') == component_name then
                vim.cmd('edit ' .. component.path)
                return
            end
        end
        ui.warn('Could not find component class for view')
    else
        ui.info('Not in a Livewire component or view file')
    end
end

return M
