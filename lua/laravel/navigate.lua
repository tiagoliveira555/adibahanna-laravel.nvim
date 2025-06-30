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

-- Check if current context is Laravel-specific and should use Laravel navigation
function M.is_laravel_navigation_context()
    local line = vim.fn.getline('.')
    local word = vim.fn.expand('<cword>')

    -- Check for Laravel helper functions
    local laravel_patterns = {
        -- Navigation helpers
        'route%s*%(',
        'view%s*%(',
        'config%s*%(',
        '__%s*%(',
        'trans%s*%(',
        'env%s*%(',
        'Inertia%s*::%s*render%s*%(',
        'inertia%s*%(',

        -- URL helpers
        'action%s*%(',
        'asset%s*%(',
        'secure_asset%s*%(',
        'secure_url%s*%(',
        'to_route%s*%(',
        'url%s*%(',

        -- Path helpers
        'app_path%s*%(',
        'base_path%s*%(',
        'config_path%s*%(',
        'database_path%s*%(',
        'lang_path%s*%(',
        'public_path%s*%(',
        'resource_path%s*%(',
        'storage_path%s*%(',

        -- Other common helpers that might reference files
        'mix%s*%(',
        'policy%s*%(',
    }

    for _, pattern in ipairs(laravel_patterns) do
        if line:match(pattern) then
            return true
        end
    end

    -- Check if we're in a quoted string that looks like a Laravel path
    local col = vim.fn.col('.')
    local before_cursor = line:sub(1, col - 1)
    local after_cursor = line:sub(col)

    -- Find if we're inside quotes
    local quote_start = before_cursor:find("['\"][^'\"]*$")
    local quote_end = after_cursor:find("['\"]")

    if quote_start and quote_end then
        local full_string = before_cursor:sub(quote_start + 1) .. after_cursor:sub(1, quote_end - 1)

        -- Check if the string looks like a Laravel pattern
        if full_string:match('^[a-z]+%.[a-z]+') or -- route names like 'user.show'
            full_string:match('/') or              -- view paths like 'users/show'
            full_string:match('%.') then           -- config keys like 'app.name'
            -- Make sure we're in a Laravel function context
            for _, pattern in ipairs(laravel_patterns) do
                if line:match(pattern) then
                    return true
                end
            end
        end
    end

    return false
end

-- Helper: Get joined lines around the cursor for multi-line function call extraction
local function get_surrounding_lines_joined(window, num_lines)
    window = window or 0
    num_lines = num_lines or 3
    local curr_line = vim.fn.line('.')
    local start_line = math.max(1, curr_line - num_lines)
    local end_line = curr_line + num_lines
    local lines = vim.api.nvim_buf_get_lines(vim.api.nvim_get_current_buf(), start_line - 1, end_line, false)
    return table.concat(lines, ' ')
end

-- Enhanced Laravel string navigation - detects context and navigates to appropriate file
function M.goto_laravel_string()
    local col = vim.fn.col('.')
    local context = nil

    -- First try single-line extraction (more precise)
    local line = vim.fn.getline('.')

    local function extract_laravel_call(line, func_name)
        local escaped_func = func_name:gsub('([%(%)%[%]%*%+%-%?%^%$%%::])', '%%%1')
        local patterns = {
            escaped_func .. "%s*%(%s*['\"]([^'\"]+)['\"]",      -- Basic pattern
            escaped_func .. "%s*%(%s*['\"]([^'\"]*)['\"]%s*,",  -- With comma after
            escaped_func .. "%s*%(%s*['\"]([^'\"]*)['\"]%s*%)", -- With closing paren
        }
        for _, pattern in ipairs(patterns) do
            local match = line:match(pattern)
            if match then
                return match
            end
        end
        return nil
    end

    local laravel_functions = {
        -- Navigation helpers
        { name = 'route',           type = 'route' },
        { name = 'view',            type = 'view' },
        { name = 'Inertia::render', type = 'view' },
        { name = 'inertia',         type = 'view' },
        { name = 'config',          type = 'config' },
        { name = '__',              type = 'trans' },
        { name = 'trans',           type = 'trans' },
        { name = 'env',             type = 'env' },
        -- URL helpers that reference routes
        { name = 'action',          type = 'route' },
        { name = 'to_route',        type = 'route' },
        -- Asset helpers
        { name = 'asset',           type = 'asset' },
        { name = 'secure_asset',    type = 'asset' },
        { name = 'mix',             type = 'asset' },
    }

    -- Try single-line extraction first (more precise)
    for _, func in ipairs(laravel_functions) do
        local match = extract_laravel_call(line, func.name)
        if match then
            context = { func = func.type, partial = match }
            break
        end
    end

    -- Fallback to multi-line extraction only if single-line fails
    if not context then
        local joined_lines = get_surrounding_lines_joined(0, 3)

        local function extract_laravel_call_multiline(text, func_name)
            local escaped_func = func_name:gsub('([%(%)%[%]%*%+%-%?%^%$%%::])', '%%%1')
            local patterns = {
                escaped_func .. "%s*%(%s*['\"]([^'\"]+)['\"]",      -- Basic pattern
                escaped_func .. "%s*%(%s*['\"]([^'\"]*)['\"]%s*,",  -- With comma after
                escaped_func .. "%s*%(%s*['\"]([^'\"]*)['\"]%s*%)", -- With closing paren
            }
            for _, pattern in ipairs(patterns) do
                local match = text:match(pattern)
                if match then
                    return match
                end
            end
            return nil
        end

        for _, func in ipairs(laravel_functions) do
            local match = extract_laravel_call_multiline(joined_lines, func.name)
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

        -- Find the quoted string we're in - more robust approach
        local quote_char = nil
        local quote_start_pos = nil

        -- Look for the opening quote
        for i = col - 1, 1, -1 do
            local char = line:sub(i, i)
            if char == '"' or char == "'" then
                quote_char = char
                quote_start_pos = i
                break
            end
        end

        if quote_char and quote_start_pos then
            -- Find the closing quote
            local quote_end_pos = nil
            for i = col, #line do
                local char = line:sub(i, i)
                if char == quote_char then
                    quote_end_pos = i
                    break
                end
            end

            if quote_end_pos then
                local full_string = line:sub(quote_start_pos + 1, quote_end_pos - 1)

                -- Try to guess the type based on string content and surrounding context
                if (line:match('route%s*%(') or line:match('to_route%s*%(') or line:match('action%s*%(')) and full_string:match('^[a-z]+%.[a-z]+') then
                    context = { func = 'route', partial = full_string }
                elseif (line:match('route%s*%(') or line:match('to_route%s*%(') or line:match('action%s*%(')) then
                    -- If it doesn't match the dotted pattern but is in a route function, still treat as route
                    context = { func = 'route', partial = full_string }
                elseif (line:match('view%s*%(') or line:match('Inertia%s*::%s*render%s*%(')) and (full_string:match('/') or full_string:match('%.')) then
                    context = { func = 'view', partial = full_string }
                elseif line:match('config%s*%(') and full_string:match('%.') then
                    context = { func = 'config', partial = full_string }
                elseif (line:match('__%s*%(') or line:match('trans%s*%(')) then
                    context = { func = 'trans', partial = full_string }
                elseif line:match('env%s*%(') then
                    context = { func = 'env', partial = full_string }
                end
            end
        end
    end

    if not context then
        return false
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
    elseif context.func == 'env' then
        M.goto_env(context.partial)
    elseif context.func == 'asset' then
        M.goto_asset(context.partial)
    else
        return false
    end

    return true
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

    local found = false
    for _, route_file in ipairs(route_files) do
        if vim.fn.filereadable(route_file) == 1 then
            local lines = vim.fn.readfile(route_file)
            -- Join lines in windows of 3 to catch multi-line route definitions
            local window = 3
            for i = 1, #lines do
                local chunk = {}
                for j = 0, window - 1 do
                    if lines[i + j] then
                        table.insert(chunk, lines[i + j])
                    end
                end
                local joined = table.concat(chunk, ' ')
                local pattern = '->name%s*%(%s*[\'"]' .. vim.pesc(route_name) .. '[\'"]'
                if joined:match(pattern) then
                    vim.cmd('edit ' .. route_file)
                    vim.fn.cursor(i, 1)
                    vim.cmd('normal! zz')
                    ui.info('Found route: ' .. route_name)
                    found = true
                    break
                end
            end
            if found then break end
        end
    end

    if not found then
        ui.warn('Route not found: ' .. route_name)
    end
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

-- Navigate to environment variable in .env file
function M.goto_env(env_key)
    if not env_key or env_key == '' then
        ui.warn('No environment variable provided')
        return
    end

    local root = get_project_root()
    if not root then
        ui.error('Not in a Laravel project')
        return
    end

    -- Try different .env files
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
            for i, line in ipairs(lines) do
                -- Look for the environment variable
                if line:match('^' .. vim.pesc(env_key) .. '%s*=') then
                    vim.cmd('edit ' .. env_file)
                    vim.fn.cursor(i, 1)
                    vim.cmd('normal! zz')
                    ui.info('Found environment variable: ' .. env_key .. ' in ' .. vim.fn.fnamemodify(env_file, ':t'))
                    return
                end
            end
        end
    end

    -- If not found, open the main .env file anyway
    local main_env = root .. '/.env'
    if vim.fn.filereadable(main_env) == 1 then
        vim.cmd('edit ' .. main_env)
        ui.warn('Environment variable "' .. env_key .. '" not found, but opened .env file')
    else
        ui.warn('No .env file found in project root')
    end
end

-- Navigate to asset file
function M.goto_asset(asset_path)
    if not asset_path or asset_path == '' then
        ui.warn('No asset path provided')
        return
    end

    local root = get_project_root()
    if not root then
        ui.error('Not in a Laravel project')
        return
    end

    -- Try different asset locations
    local asset_locations = {
        root .. '/public/' .. asset_path,
        root .. '/resources/js/' .. asset_path,
        root .. '/resources/css/' .. asset_path,
        root .. '/resources/sass/' .. asset_path,
        root .. '/resources/assets/' .. asset_path,
    }

    for _, asset_file in ipairs(asset_locations) do
        if vim.fn.filereadable(asset_file) == 1 then
            vim.cmd('edit ' .. asset_file)
            ui.info('Found asset: ' .. asset_path)
            return
        end
    end

    ui.warn('Asset file not found: ' .. asset_path)
end

-- Navigate to Laravel global function documentation or definition
function M.goto_laravel_global(global_func)
    if not global_func or global_func == '' then
        ui.warn('No global function provided')
        return
    end

    -- Map of Laravel global functions to their documentation or relevant files
    local global_mappings = {
        auth = { type = 'provider', path = '/config/auth.php', desc = 'Authentication configuration' },
        request = { type = 'docs', desc = 'Request helper - provides access to current HTTP request' },
        session = { type = 'provider', path = '/config/session.php', desc = 'Session configuration' },
        cache = { type = 'provider', path = '/config/cache.php', desc = 'Cache configuration' },
        cookie = { type = 'provider', path = '/config/session.php', desc = 'Cookie configuration in session config' },
        response = { type = 'docs', desc = 'Response helper - creates HTTP responses' },
        redirect = { type = 'docs', desc = 'Redirect helper - creates redirect responses' },
        back = { type = 'docs', desc = 'Back helper - redirects to previous page' },
        old = { type = 'docs', desc = 'Old input helper - retrieves old form input' },
        asset = { type = 'docs', desc = 'Asset helper - generates URLs for assets' },
        url = { type = 'docs', desc = 'URL helper - generates URLs' },
        secure_url = { type = 'docs', desc = 'Secure URL helper - generates HTTPS URLs' },
        action = { type = 'docs', desc = 'Action helper - generates URLs for controller actions' },
        mix = { type = 'file', path = '/webpack.mix.js', desc = 'Laravel Mix configuration' },
        app = { type = 'provider', path = '/config/app.php', desc = 'Application configuration' },
        env = { type = 'file', path = '/.env', desc = 'Environment configuration' },
        config = { type = 'provider', path = '/config', desc = 'Configuration files' },
        dd = { type = 'docs', desc = 'Dump and die helper' },
        dump = { type = 'docs', desc = 'Dump helper' },
        logger = { type = 'provider', path = '/config/logging.php', desc = 'Logging configuration' },
        validator = { type = 'provider', path = '/config/validation.php', desc = 'Validation configuration' },
        abort = { type = 'docs', desc = 'Abort helper - throws HTTP exceptions' },
    }

    local mapping = global_mappings[global_func]
    if not mapping then
        ui.info('Laravel global function: ' .. global_func .. ' - Check Laravel documentation for details')
        return
    end

    local root = get_project_root()
    if not root then
        ui.error('Not in a Laravel project')
        return
    end

    if mapping.type == 'file' or mapping.type == 'provider' then
        local file_path = root .. mapping.path

        if mapping.type == 'provider' and mapping.path == '/config' then
            -- Open config directory
            vim.cmd('edit ' .. file_path)
        elseif vim.fn.filereadable(file_path) == 1 then
            vim.cmd('edit ' .. file_path)
            ui.info('Opened ' .. mapping.desc)
        elseif vim.fn.isdirectory(file_path) == 1 then
            vim.cmd('edit ' .. file_path)
            ui.info('Opened ' .. mapping.desc)
        else
            ui.warn('File not found: ' .. file_path)
            ui.info('Laravel global function: ' .. global_func .. ' - ' .. mapping.desc)
        end
    else
        ui.info('Laravel global function: ' .. global_func .. ' - ' .. mapping.desc)
    end
end

return M
