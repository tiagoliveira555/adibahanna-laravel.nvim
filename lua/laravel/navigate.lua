-- Laravel navigation utilities
local M = {}

local ui = require('laravel.ui')

-- Get Laravel project root
local function get_project_root()
    return _G.laravel_nvim.project_root
end

-- Find controllers
function M.find_controllers()
    local root = get_project_root()
    if not root then return {} end

    local controllers_path = root .. '/app/Http/Controllers'
    if vim.fn.isdirectory(controllers_path) == 0 then
        return {}
    end

    local controllers = {}
    local function scan_directory(dir, namespace)
        namespace = namespace or 'App\\Http\\Controllers'

        -- Check if directory exists
        if vim.fn.isdirectory(dir) ~= 1 then
            return
        end

        local items = vim.fn.readdir(dir)
        if not items then
            return
        end

        for _, item in ipairs(items) do
            local full_path = dir .. '/' .. item

            if vim.fn.isdirectory(full_path) == 1 then
                -- Recursively scan subdirectories
                local subcontrollers = scan_directory(full_path, namespace .. '\\' .. item)
                for _, controller in ipairs(subcontrollers) do
                    controllers[#controllers + 1] = controller
                end
            elseif item:match('%.php$') and item:match('Controller%.php$') then
                local class_name = item:gsub('%.php$', '')
                controllers[#controllers + 1] = {
                    name = class_name,
                    namespace = namespace .. '\\' .. class_name,
                    path = full_path,
                }
            end
        end
    end

    scan_directory(controllers_path)
    return controllers
end

-- Find models
function M.find_models()
    local root = get_project_root()
    if not root then return {} end

    local models_path = root .. '/app/Models'
    local app_path = root .. '/app'

    local models = {}
    local function scan_directory(dir, namespace, is_models_dir)
        namespace = namespace or 'App'

        -- Check if directory exists
        if vim.fn.isdirectory(dir) ~= 1 then
            return
        end

        local items = vim.fn.readdir(dir)
        if not items then
            return
        end

        for _, item in ipairs(items) do
            local full_path = dir .. '/' .. item

            if vim.fn.isdirectory(full_path) == 1 then
                if item == 'Models' then
                    -- Scan Models directory
                    scan_directory(full_path, namespace .. '\\Models', true)
                elseif not item:match('^[A-Z]') and not is_models_dir then
                    -- Skip non-capitalized directories in app root (like Http, Console, etc.)
                    -- unless we're already in Models directory
                else
                    -- Recursively scan subdirectories
                    scan_directory(full_path, namespace .. '\\' .. item, is_models_dir)
                end
            elseif item:match('%.php$') then
                local class_name = item:gsub('%.php$', '')

                -- Check if this looks like a model
                local is_model = false
                if is_models_dir then
                    is_model = true
                elseif dir == app_path then
                    -- Check if it's a model in the app root (Laravel < 8 style)
                    local content = vim.fn.readfile(full_path, '', 10) -- Read first 10 lines
                    for _, line in ipairs(content) do
                        if line:match('extends.*Model') or line:match('use.*Model') then
                            is_model = true
                            break
                        end
                    end
                end

                if is_model then
                    models[#models + 1] = {
                        name = class_name,
                        namespace = namespace .. '\\' .. class_name,
                        path = full_path,
                    }
                end
            end
        end
    end

    -- First try Models directory (Laravel 8+)
    if vim.fn.isdirectory(models_path) == 1 then
        scan_directory(models_path, 'App\\Models', true)
    end

    -- Also scan app root for models (Laravel < 8)
    scan_directory(app_path, 'App', false)

    return models
end

-- Navigate to controller
function M.goto_controller(controller_name)
    if not controller_name or controller_name == '' then
        -- Show controller picker
        local controllers = M.find_controllers()
        if #controllers == 0 then
            ui.warn('No controllers found')
            return
        end

        local items = {}
        for _, controller in ipairs(controllers) do
            items[#items + 1] = controller.name
        end

        ui.select(items, {
            prompt = 'Select controller:',
            kind = 'laravel_controller',
        }, function(choice)
            if choice then
                for _, controller in ipairs(controllers) do
                    if controller.name == choice then
                        vim.cmd('edit ' .. controller.path)
                        break
                    end
                end
            end
        end)
    else
        -- Find specific controller
        local controllers = M.find_controllers()
        local found_controller = nil

        for _, controller in ipairs(controllers) do
            if controller.name:lower():match(controller_name:lower()) then
                found_controller = controller
                break
            end
        end

        if found_controller then
            vim.cmd('edit ' .. found_controller.path)
        else
            ui.error('Controller not found: ' .. controller_name)
        end
    end
end

-- Navigate to model
function M.goto_model(model_name)
    if not model_name or model_name == '' then
        -- Show model picker
        local models = M.find_models()
        if #models == 0 then
            ui.warn('No models found')
            return
        end

        local items = {}
        for _, model in ipairs(models) do
            items[#items + 1] = model.name
        end

        ui.select(items, {
            prompt = 'Select model:',
            kind = 'laravel_model',
        }, function(choice)
            if choice then
                for _, model in ipairs(models) do
                    if model.name == choice then
                        vim.cmd('edit ' .. model.path)
                        break
                    end
                end
            end
        end)
    else
        -- Find specific model
        local models = M.find_models()
        local found_model = nil

        for _, model in ipairs(models) do
            if model.name:lower():match(model_name:lower()) then
                found_model = model
                break
            end
        end

        if found_model then
            vim.cmd('edit ' .. found_model.path)
        else
            ui.error('Model not found: ' .. model_name)
        end
    end
end

-- Navigate to view
function M.goto_view(view_name)
    require('laravel.blade').goto_view(view_name)
end

-- Navigate to related files based on current context
function M.goto_related()
    local current_file = vim.fn.expand('%:p')
    local root = get_project_root()

    if not root or not current_file:find(root, 1, true) then
        ui.warn('Not in a Laravel project')
        return
    end

    local relative_path = current_file:sub(#root + 2) -- +2 for the slash
    local related_files = {}

    -- Determine current file type and find related files
    if relative_path:match('^app/Http/Controllers/') then
        -- Current file is a controller
        local controller_name = vim.fn.fnamemodify(current_file, ':t:r') -- filename without extension
        local base_name = controller_name:gsub('Controller$', '')

        -- Look for related model
        local models = M.find_models()
        for _, model in ipairs(models) do
            if model.name == base_name or model.name == base_name:gsub('s$', '') then -- Handle plurals
                related_files[#related_files + 1] = {
                    type = 'Model',
                    name = model.name,
                    path = model.path,
                }
            end
        end

        -- Look for related views
        local views = require('laravel.blade').find_views()
        local view_prefix = base_name:lower()
        for _, view in ipairs(views) do
            if view.name:match('^' .. view_prefix) then
                related_files[#related_files + 1] = {
                    type = 'View',
                    name = view.name,
                    path = view.path,
                }
            end
        end
    elseif relative_path:match('^app/Models/') or relative_path:match('^app/.*%.php$') then
        -- Current file is a model
        local model_name = vim.fn.fnamemodify(current_file, ':t:r')

        -- Look for related controller
        local controllers = M.find_controllers()
        local controller_patterns = { model_name .. 'Controller', model_name .. 'sController' }

        for _, controller in ipairs(controllers) do
            for _, pattern in ipairs(controller_patterns) do
                if controller.name == pattern then
                    related_files[#related_files + 1] = {
                        type = 'Controller',
                        name = controller.name,
                        path = controller.path,
                    }
                    break
                end
            end
        end

        -- Look for related migration
        local migrations_path = root .. '/database/migrations'
        if vim.fn.isdirectory(migrations_path) == 1 then
            local migrations = vim.fn.readdir(migrations_path)
            if migrations then
                local table_name = model_name:lower() .. 's' -- Simple pluralization

                for _, migration in ipairs(migrations) do
                    if migration:match(table_name) then
                        related_files[#related_files + 1] = {
                            type = 'Migration',
                            name = migration,
                            path = migrations_path .. '/' .. migration,
                        }
                        break
                    end
                end
            end
        end
    elseif relative_path:match('%.blade%.php$') then
        -- Current file is a view
        local view_name = require('laravel.blade').get_current_view_name()
        if view_name then
            local view_parts = vim.split(view_name, '%.')
            local controller_name = vim.fn.substitute(view_parts[1], '^.', '\\u&', '') .. 'Controller'

            -- Look for related controller
            local controllers = M.find_controllers()
            for _, controller in ipairs(controllers) do
                if controller.name == controller_name then
                    related_files[#related_files + 1] = {
                        type = 'Controller',
                        name = controller.name,
                        path = controller.path,
                    }
                    break
                end
            end
        end
    end

    -- Show related files
    if #related_files == 0 then
        ui.info('No related files found')
        return
    end

    local items = {}
    for _, file in ipairs(related_files) do
        items[#items + 1] = file.type .. ': ' .. file.name
    end

    ui.select(items, {
        prompt = 'Select related file:',
        kind = 'laravel_related',
    }, function(choice)
        if choice then
            local index = nil
            for i, item in ipairs(items) do
                if item == choice then
                    index = i
                    break
                end
            end

            if index and related_files[index] then
                vim.cmd('edit ' .. related_files[index].path)
            end
        end
    end)
end

-- Smart navigation command
function M.smart_goto()
    local word = vim.fn.expand('<cword>')

    if not word or word == '' then
        M.goto_related()
        return
    end

    -- Try to determine what the word under cursor refers to
    local current_line = vim.fn.getline('.')

    -- Check for route references
    if current_line:match('route%s*%(%s*[\'"]' .. word) then
        ui.info('Route navigation not yet implemented: ' .. word)
        return
    end

    -- Check for view references
    if current_line:match('view%s*%(%s*[\'"]' .. word) or current_line:match('@include%s*%(%s*[\'"]' .. word) then
        M.goto_view(word)
        return
    end

    -- Check for model references (simple heuristic)
    if word:match('^[A-Z]') then
        -- Looks like a class name
        local models = M.find_models()
        for _, model in ipairs(models) do
            if model.name == word then
                vim.cmd('edit ' .. model.path)
                return
            end
        end

        local controllers = M.find_controllers()
        for _, controller in ipairs(controllers) do
            if controller.name == word then
                vim.cmd('edit ' .. controller.path)
                return
            end
        end
    end

    -- Fallback to showing related files
    M.goto_related()
end

return M
