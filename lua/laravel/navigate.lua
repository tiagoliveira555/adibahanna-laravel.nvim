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

-- Find route files
function M.find_route_files()
    local root = get_project_root()
    if not root then
        return {}
    end

    local routes_dir = root .. '/routes'
    if vim.fn.isdirectory(routes_dir) == 0 then
        return {}
    end

    local route_files = {}
    local files = vim.fn.glob(routes_dir .. '/*.php', false, true)

    for _, file in ipairs(files) do
        local name = vim.fn.fnamemodify(file, ':t:r') -- filename without extension
        table.insert(route_files, {
            name = name,
            path = file,
            relative_path = 'routes/' .. name .. '.php'
        })
    end

    -- Sort by name
    table.sort(route_files, function(a, b)
        return a.name < b.name
    end)

    return route_files
end

-- Navigate to route file
function M.goto_route_file(route_name)
    if not route_name or route_name == '' then
        -- Show route file picker
        local route_files = M.find_route_files()
        if #route_files == 0 then
            ui.warn('No route files found')
            return
        end

        local items = {}
        for _, route_file in ipairs(route_files) do
            items[#items + 1] = route_file.name
        end

        ui.select(items, {
            prompt = 'Select route file:',
            kind = 'laravel_route_file',
        }, function(choice)
            if choice then
                for _, route_file in ipairs(route_files) do
                    if route_file.name == choice then
                        vim.cmd('edit ' .. route_file.path)
                        break
                    end
                end
            end
        end)
    else
        -- Find specific route file
        local route_files = M.find_route_files()
        local found_route = nil

        for _, route_file in ipairs(route_files) do
            if route_file.name:lower():match(route_name:lower()) then
                found_route = route_file
                break
            end
        end

        if found_route then
            vim.cmd('edit ' .. found_route.path)
        else
            ui.error('Route file not found: ' .. route_name)
        end
    end
end

-- Enhanced Laravel string navigation - detects context and navigates to appropriate file
function M.goto_laravel_string()
    local line = vim.fn.getline('.')
    local col = vim.fn.col('.')

    -- Get the completion context to understand what Laravel function we're in
    local completion_source = require('laravel.completion_source')
    local context = completion_source.get_completion_context and
        completion_source.get_completion_context(line, col - 1)

    if not context then
        -- Fallback: try to detect Laravel patterns manually with full string extraction
        -- Better pattern matching that captures complete strings
        local function extract_laravel_call(line, func_name)
            -- Pattern to match: func_name('string') or func_name("string")
            local pattern = func_name .. "%s*%(%s*['\"]([^'\"]*)['\"]"
            local match = line:match(pattern)
            return match
        end

        local laravel_functions = {
            { name = 'route',           type = 'route' },
            { name = 'view',            type = 'view' },
            { name = 'Inertia::render', type = 'view' },
            { name = 'inertia',         type = 'view' },
            { name = 'config',          type = 'config' },
            { name = '__',              type = 'trans' },
            { name = 'trans',           type = 'trans' },
        }

        for _, func in ipairs(laravel_functions) do
            local match = extract_laravel_call(line, func.name)
            if match then
                context = { func = func.type, partial = match }
                break
            end
        end
    end

    if not context then
        -- Last resort: check if cursor is on a quoted string and try to guess context
        local before_cursor = line:sub(1, col - 1)
        local after_cursor = line:sub(col)

        -- Find the quoted string we're in
        local quote_start = before_cursor:find("['\"][^'\"]*$")
        local quote_end = after_cursor:find("['\"]")

        if quote_start and quote_end then
            local full_string = before_cursor:sub(quote_start + 1) .. after_cursor:sub(1, quote_end - 1)

            -- Try to guess the type based on string content
            if full_string:match('^[a-z]+%.[a-z]+') then
                context = { func = 'route', partial = full_string }
            elseif full_string:match('/') or full_string:match('%.') then
                context = { func = 'view', partial = full_string }
            end
        end
    end

    if not context then
        ui.warn('Not in a Laravel helper function or string')
        return
    end

    -- Navigate based on the detected context
    if context.func == 'route' then
        M.goto_route_definition(context.partial)
    elseif context.func == 'view' then
        M.goto_view(context.partial)
    elseif context.func == 'config' then
        M.goto_config(context.partial)
    elseif context.func == 'trans' or context.func == '__' then
        M.goto_translation(context.partial)
    else
        ui.warn('Unknown Laravel function type: ' .. context.func)
    end
end

-- Navigate to route definition by name
function M.goto_route_definition(route_name)
    if not route_name or route_name == '' then
        ui.warn('No route name provided')
        return
    end

    local root = get_project_root()
    if not root then
        ui.error('Not in a Laravel project')
        return
    end

    local route_files = {
        root .. '/routes/web.php',
        root .. '/routes/api.php',
        root .. '/routes/channels.php',
        root .. '/routes/console.php'
    }

    for _, route_file in ipairs(route_files) do
        if vim.fn.filereadable(route_file) == 1 then
            local lines = vim.fn.readfile(route_file)
            for i, line in ipairs(lines) do
                -- Look for named routes
                if line:match('->name%s*%(%s*[\'"]' .. vim.pesc(route_name) .. '[\'"]') then
                    vim.cmd('edit ' .. route_file)
                    vim.fn.cursor(i, 1)
                    vim.cmd('normal! zz')
                    ui.info('Found route: ' .. route_name)
                    return
                end
            end
        end
    end

    ui.warn('Route not found: ' .. route_name)
end

-- Navigate to config file
function M.goto_config(config_key)
    if not config_key or config_key == '' then
        ui.warn('No config key provided')
        return
    end

    local root = get_project_root()
    if not root then
        ui.error('Not in a Laravel project')
        return
    end

    -- Extract the config file from the key (e.g., 'app.name' -> 'app')
    local config_file = config_key:match('^([^%.]+)')
    if not config_file then
        config_file = config_key
    end

    local config_path = root .. '/config/' .. config_file .. '.php'

    if vim.fn.filereadable(config_path) == 1 then
        vim.cmd('edit ' .. config_path)

        -- Try to find the specific key
        if config_key:find('%.') then
            local key_parts = {}
            for part in config_key:gmatch('[^%.]+') do
                table.insert(key_parts, part)
            end

            -- Skip the first part (file name) and search for the nested key
            if #key_parts > 1 then
                local search_key = key_parts[2]
                vim.fn.search("'" .. search_key .. "'\\|\"" .. search_key .. "\"", 'w')
            end
        end

        vim.cmd('normal! zz')
        ui.info('Found config: ' .. config_key)
    else
        ui.warn('Config file not found: ' .. config_file .. '.php')
    end
end

-- Navigate to translation file
function M.goto_translation(trans_key)
    if not trans_key or trans_key == '' then
        ui.warn('No translation key provided')
        return
    end

    local root = get_project_root()
    if not root then
        ui.error('Not in a Laravel project')
        return
    end

    -- Extract the translation file from the key (e.g., 'auth.failed' -> 'auth')
    local trans_file = trans_key:match('^([^%.]+)')
    if not trans_file then
        trans_file = trans_key
    end

    -- Try different language directories
    local lang_dirs = { root .. '/lang/en', root .. '/resources/lang/en' }

    for _, lang_dir in ipairs(lang_dirs) do
        local trans_path = lang_dir .. '/' .. trans_file .. '.php'

        if vim.fn.filereadable(trans_path) == 1 then
            vim.cmd('edit ' .. trans_path)

            -- Try to find the specific key
            if trans_key:find('%.') then
                local key_parts = {}
                for part in trans_key:gmatch('[^%.]+') do
                    table.insert(key_parts, part)
                end

                -- Skip the first part (file name) and search for the nested key
                if #key_parts > 1 then
                    local search_key = key_parts[2]
                    vim.fn.search("'" .. search_key .. "'\\|\"" .. search_key .. "\"", 'w')
                end
            end

            vim.cmd('normal! zz')
            ui.info('Found translation: ' .. trans_key)
            return
        end
    end

    ui.warn('Translation file not found: ' .. trans_file .. '.php')
end

return M
