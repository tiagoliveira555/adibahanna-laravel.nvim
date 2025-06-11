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
                scan_directory(full_path, namespace .. '\\' .. item)
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
    local seen_names = {} -- Track seen model names to prevent duplicates

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

                -- Skip if we've already seen this model name
                if seen_names[class_name] then
                    goto continue
                end

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
                    seen_names[class_name] = true
                    models[#models + 1] = {
                        name = class_name,
                        namespace = namespace .. '\\' .. class_name,
                        path = full_path,
                    }
                end

                ::continue::
            end
        end
    end

    -- First scan Models directory (Laravel 8+) - prioritize this
    if vim.fn.isdirectory(models_path) == 1 then
        scan_directory(models_path, 'App\\Models', true)
    end

    -- Only scan app root for models (Laravel < 8) if Models directory doesn't exist
    if vim.fn.isdirectory(models_path) == 0 then
        scan_directory(app_path, 'App', false)
    end

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

-- Show context-aware related views
function M.show_related_views()
    local current_file = vim.fn.expand('%:p')
    local root = get_project_root()

    -- Debug information
    print('Debug: Current file:', current_file)
    print('Debug: Project root:', root)

    if not root or not current_file:find(root, 1, true) then
        ui.warn('Not in a Laravel project')
        return
    end

    local relative_path = current_file:sub(#root + 2) -- +2 for the slash
    local related_views = {}
    local context_name = nil

    -- Debug information
    print('Debug: Relative path:', relative_path)

    -- Determine context and find related views
    if relative_path:match('^app/Http/Controllers/') then
        print('Debug: Detected controller file')
        -- In a controller file
        local controller_name = vim.fn.fnamemodify(current_file, ':t:r') -- filename without extension
        local base_name = controller_name:gsub('Controller$', '')
        context_name = base_name .. ' Controller'

        print('Debug: Controller name:', controller_name)
        print('Debug: Base name:', base_name)

        -- Read controller content to find actual view calls
        local content = vim.fn.readfile(current_file)
        local view_patterns = {}

        -- Look for view() calls and Inertia::render() calls
        for _, line in ipairs(content) do
            -- Traditional Laravel views: view('auth.register'), view("posts.show")
            local view_match = line:match("view%s*%(%s*['\"]([^'\"]+)['\"]")
            if view_match then
                print('Debug: Found view() call:', view_match)
                table.insert(view_patterns, view_match)
            end

            -- Inertia views: Inertia::render('auth/register'), Inertia::render("Posts/Show")
            local inertia_match = line:match("Inertia::render%s*%(%s*['\"]([^'\"]+)['\"]")
            if inertia_match then
                print('Debug: Found Inertia::render() call:', inertia_match)
                -- Convert Inertia path to view name (auth/register -> auth.register)
                local view_name = inertia_match:gsub('/', '.')
                table.insert(view_patterns, view_name)
            end
        end

        -- If no specific view calls found, fall back to controller name pattern
        if #view_patterns == 0 then
            local view_prefix = base_name:lower()
            print('Debug: No specific views found, using controller prefix:', view_prefix)
            table.insert(view_patterns, view_prefix)
        end

        -- Find views that match the detected patterns
        local views = require('laravel.blade').find_views()
        print('Debug: Found', #views, 'total views')
        print('Debug: View patterns to match:', vim.inspect(view_patterns))

        for _, pattern in ipairs(view_patterns) do
            -- Extract prefix from pattern (auth.register -> auth)
            local prefix = pattern:match('([^%.]+)') or pattern

            for _, view in ipairs(views) do
                print('Debug: Checking view:', view.name, 'against prefix:', prefix)
                -- Match views with same prefix
                if view.name:match('^' .. prefix .. '%.') or
                    view.name:match('^' .. prefix .. '$') or
                    view.name:match('^' .. prefix .. '/') or
                    view.name == pattern then
                    print('Debug: Match found:', view.name)
                    related_views[#related_views + 1] = {
                        name = view.name,
                        path = view.path,
                        match_type = 'controller_view'
                    }
                end
            end
        end
    elseif relative_path:match('^routes/') then
        -- In a route file - try to detect view context from cursor position
        local current_line = vim.api.nvim_get_current_line()
        local cursor_pos = vim.api.nvim_win_get_cursor(0)
        local line_num = cursor_pos[1]

        -- Look for view() calls around the cursor
        local view_name = nil

        -- Check current line and a few lines around it
        for i = math.max(1, line_num - 2), math.min(vim.fn.line('$'), line_num + 2) do
            local line = vim.fn.getline(i)
            local match = line:match("view%s*%(%s*['\"]([^'\"]+)['\"]")
            if match then
                view_name = match
                break
            end
        end

        if view_name then
            context_name = 'Route: ' .. view_name
            local views = require('laravel.blade').find_views()

            -- Find views related to the detected view
            local view_parts = vim.split(view_name, '%.')
            local prefix = view_parts[1]

            for _, view in ipairs(views) do
                if view.name:match('^' .. prefix .. '%.') or view.name:match('^' .. prefix .. '$') or
                    view.name:match('^' .. prefix .. '/') then
                    related_views[#related_views + 1] = {
                        name = view.name,
                        path = view.path,
                        match_type = 'route_related'
                    }
                end
            end
        else
            ui.info('No view context detected in current route')
            return
        end
    elseif relative_path:match('%.blade%.php$') then
        -- In a view file - show sibling views
        local view_name = require('laravel.blade').get_current_view_name()
        if view_name then
            local view_parts = vim.split(view_name, '%.')
            local prefix = view_parts[1]
            context_name = 'Views: ' .. prefix .. '.*'

            local views = require('laravel.blade').find_views()
            for _, view in ipairs(views) do
                if view.name ~= view_name and
                    (view.name:match('^' .. prefix .. '%.') or view.name:match('^' .. prefix .. '/')) then
                    related_views[#related_views + 1] = {
                        name = view.name,
                        path = view.path,
                        match_type = 'sibling'
                    }
                end
            end
        else
            ui.warn('Could not determine view context')
            return
        end
    else
        ui.info('No view context detected for current file type')
        return
    end

    -- Remove duplicates (in case a view matches multiple patterns)
    local seen = {}
    local unique_views = {}
    for _, view in ipairs(related_views) do
        if not seen[view.name] then
            seen[view.name] = true
            unique_views[#unique_views + 1] = view
        end
    end

    print('Debug: Found', #unique_views, 'unique related views')

    if #unique_views == 0 then
        ui.info('No related views found for ' .. (context_name or 'current context'))
        return
    end

    -- Sort views by name for better organization
    table.sort(unique_views, function(a, b) return a.name < b.name end)

    -- Show view picker
    local items = {}
    for _, view in ipairs(unique_views) do
        items[#items + 1] = view.name
    end

    ui.select(items, {
        prompt = 'Related views (' .. (context_name or 'current context') .. '):',
        kind = 'laravel_related_views',
    }, function(choice)
        if choice then
            for _, view in ipairs(unique_views) do
                if view.name == choice then
                    vim.cmd('edit ' .. view.path)
                    break
                end
            end
        end
    end)
end

return M
