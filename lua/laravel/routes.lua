-- Laravel routes management
local M = {}

local ui = require('laravel.ui')
local artisan = require('laravel.artisan')

-- Cache for routes
local routes_cache = {}
local cache_timestamp = 0
local cache_duration = 60 -- 1 minute

-- Get cached routes or fetch new ones
local function get_routes(callback)
    local current_time = os.time()

    -- Use cache if available and not expired
    if routes_cache.data and (current_time - cache_timestamp) < cache_duration then
        callback(routes_cache.data)
        return
    end

    -- Fetch routes from artisan
    artisan.get_routes(function(routes)
        routes_cache.data = routes
        cache_timestamp = current_time
        callback(routes)
    end)
end

-- Color and styling helpers
local function get_method_color(method)
    local colors = {
        GET = '🟢',
        POST = '🔵',
        PUT = '🟡',
        PATCH = '🟠',
        DELETE = '🔴',
        OPTIONS = '⚪',
        HEAD = '⚫',
    }
    return colors[method] or '⚪'
end

local function get_method_highlight(method)
    local highlights = {
        GET = 'String',      -- Green-ish
        POST = 'Function',   -- Blue-ish
        PUT = 'Constant',    -- Yellow-ish
        PATCH = 'Number',    -- Orange-ish
        DELETE = 'Error',    -- Red
        OPTIONS = 'Comment', -- Gray
        HEAD = 'Comment',    -- Gray
    }
    return highlights[method] or 'Normal'
end

-- Enhanced format route for display
local function format_route(route, max_widths)
    -- Handle different possible data structures from Laravel
    local methods = route.methods or route.method or {}
    if type(methods) == 'string' then
        methods = { methods }
    end

    local method_str = table.concat(methods, '|')

    -- Safely handle potential userdata values from JSON
    local uri = ''
    if route.uri then
        if type(route.uri) == 'string' then
            uri = route.uri
        else
            uri = tostring(route.uri) or ''
        end
    elseif route.url then
        if type(route.url) == 'string' then
            uri = route.url
        else
            uri = tostring(route.url) or ''
        end
    end

    local name = ''
    if route.name then
        if type(route.name) == 'string' then
            name = route.name
        else
            name = tostring(route.name) or ''
        end
    end

    local action = ''
    if route.action then
        if type(route.action) == 'string' then
            action = route.action
        else
            action = tostring(route.action) or ''
        end
    elseif route.uses then
        if type(route.uses) == 'string' then
            action = route.uses
        else
            action = tostring(route.uses) or ''
        end
    end

    -- Clean up action for better display
    if type(action) == 'table' and action.uses then
        action = action.uses
    end

    -- Extract controller and method from action
    local controller, method = '', ''
    if action then
        if action:match('@') then
            controller, method = action:match('([^@\\]+)@([^@]+)$')
            if not controller then
                controller = action:match('([^@\\]+)@') or action
            end
        elseif action:match('\\') then
            controller = action:match('([^\\]+)$') or action
        else
            controller = action
        end
    end

    -- Apply padding based on max widths
    local padded_method = string.format('%-' .. max_widths.method .. 's', method_str)
    local padded_uri = string.format('%-' .. max_widths.uri .. 's', uri)
    local padded_name = string.format('%-' .. max_widths.name .. 's', name)

    return {
        methods = methods,
        method_str = method_str,
        uri = uri,
        name = name,
        action = action,
        controller = controller,
        method_name = method,
        padded_method = padded_method,
        padded_uri = padded_uri,
        padded_name = padded_name,
        route = route,
    }
end

-- Calculate optimal column widths
local function calculate_max_widths(routes)
    local max_widths = {
        method = 8, -- minimum width for "METHOD"
        uri = 20,   -- minimum width for URI
        name = 15,  -- minimum width for NAME
    }

    for _, route in ipairs(routes) do
        local methods = route.methods or route.method or {}
        if type(methods) == 'string' then
            methods = { methods }
        end

        local method_str = table.concat(methods, '|')

        -- Safely handle potential userdata values from JSON
        local uri = ''
        if route.uri and type(route.uri) == 'string' then
            uri = route.uri
        elseif route.url and type(route.url) == 'string' then
            uri = route.url
        end

        local name = ''
        if route.name then
            if type(route.name) == 'string' then
                name = route.name
            else
                -- Handle non-string values (like userdata from JSON nulls)
                name = tostring(route.name) or ''
            end
        end

        -- Ensure all values are strings before getting length
        method_str = tostring(method_str) or ''
        uri = tostring(uri) or ''
        name = tostring(name) or ''

        max_widths.method = math.max(max_widths.method, #method_str)
        max_widths.uri = math.max(max_widths.uri, #uri)
        max_widths.name = math.max(max_widths.name, #name)
    end

    -- Cap the widths to reasonable maximums
    max_widths.method = math.min(max_widths.method, 15)
    max_widths.uri = math.min(max_widths.uri, 50)
    max_widths.name = math.min(max_widths.name, 30)

    return max_widths
end

-- Show routes in a clean table format
function M.show_routes()
    get_routes(function(routes)
        if not routes or #routes == 0 then
            ui.warn('No routes found')
            return
        end

        -- Calculate optimal column widths
        local max_widths = calculate_max_widths(routes)

        -- Add some padding for readability
        max_widths.method = max_widths.method + 2
        max_widths.uri = max_widths.uri + 2
        max_widths.name = max_widths.name + 2

        -- Format routes
        local formatted_routes = {}
        local content_lines = {}

        -- Create clean header
        local header = string.format(
            '%-' .. max_widths.method .. 's %-' .. max_widths.uri .. 's %-' .. max_widths.name .. 's %s',
            'METHOD', 'URI', 'NAME', 'ACTION'
        )
        local separator = string.rep('─', #header)

        table.insert(content_lines, header)
        table.insert(content_lines, separator)

        -- Add routes with clean formatting
        for _, route in ipairs(routes) do
            local formatted = format_route(route, max_widths)
            table.insert(formatted_routes, formatted)

            -- Get method icon
            local method_icon = ''
            if #formatted.methods > 0 then
                method_icon = get_method_color(formatted.methods[1])
            end

            -- Create clean route line
            local route_line = string.format(
                '%s %-' .. (max_widths.method - 2) .. 's %-' .. max_widths.uri .. 's %-' .. max_widths.name .. 's %s',
                method_icon,
                table.concat(formatted.methods, '|'),
                formatted.uri,
                formatted.name,
                formatted.controller or formatted.action or ''
            )

            table.insert(content_lines, route_line)
        end

        -- Add help text
        table.insert(content_lines, '')
        table.insert(content_lines,
            'Press <CR> to navigate • r to refresh • f to filter • m for method filter • q to close')

        -- Calculate window size based on content
        local max_line_length = 0
        for _, line in ipairs(content_lines) do
            max_line_length = math.max(max_line_length, vim.fn.strwidth(line))
        end

        local width = math.min(math.max(max_line_length + 4, 80), vim.o.columns - 4)
        local height = math.min(#content_lines + 2, vim.o.lines - 4)

        -- Show in floating window
        local float = ui.create_float({
            content = content_lines,
            title = ' 🚀 Laravel Routes ',
            width = width,
            height = height,
            border = 'rounded',
        })

        -- Set up syntax highlighting
        vim.api.nvim_buf_set_option(float.buf, 'filetype', 'laravel-routes')

        -- Custom syntax highlighting
        vim.cmd([[
            syntax clear
            syntax match LaravelRouteMethod /\v(GET|POST|PUT|PATCH|DELETE|HEAD|OPTIONS)/
            syntax match LaravelRouteIcon /[🟢🔵🟡🟠🔴⚪⚫]/
            syntax match LaravelRouteUri /\/[^\s]*/
            syntax match LaravelRouteName /\w\+\.\w\+/
            syntax match LaravelRouteController /[A-Z]\w*Controller/
            syntax match LaravelRouteSeparator /─\+/
            syntax match LaravelRouteHelp /Press.*close$/

            highlight link LaravelRouteMethod Keyword
            highlight link LaravelRouteIcon Special
            highlight link LaravelRouteUri String
            highlight link LaravelRouteName Identifier
            highlight link LaravelRouteController Function
            highlight link LaravelRouteSeparator Comment
            highlight link LaravelRouteHelp Comment
        ]])

        -- Enhanced navigation keymaps
        vim.keymap.set('n', '<CR>', function()
            local current_line = vim.api.nvim_win_get_cursor(0)[1]
            local route_index = current_line - 2 -- Account for header and separator

            if route_index > 0 and route_index <= #formatted_routes then
                local selected_route = formatted_routes[route_index]
                float.close()

                if selected_route.controller and selected_route.controller ~= '' then
                    -- Navigate to controller
                    require('laravel.navigate').goto_controller(selected_route.controller)
                elseif selected_route.name then
                    -- Try to find route definition by name
                    M.navigate_to_route_definition(selected_route.route)
                else
                    ui.info('No controller or route name found for navigation')
                end
            end
        end, { buffer = float.buf, silent = true, desc = 'Navigate to route' })

        vim.keymap.set('n', 'r', function()
            M.clear_cache()
            float.close()
            vim.defer_fn(function()
                M.show_routes()
            end, 100)
        end, { buffer = float.buf, silent = true, desc = 'Refresh routes' })

        vim.keymap.set('n', 'f', function()
            -- Filter routes
            vim.ui.input({ prompt = 'Filter routes (URI): ' }, function(filter)
                if filter and filter ~= '' then
                    float.close()
                    M.show_filtered_routes(filter)
                end
            end)
        end, { buffer = float.buf, silent = true, desc = 'Filter routes' })

        vim.keymap.set('n', 'm', function()
            -- Filter by method
            ui.select({ 'GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'HEAD', 'OPTIONS' }, {
                prompt = 'Filter by method:',
            }, function(method)
                if method then
                    float.close()
                    M.show_routes_by_method(method)
                end
            end)
        end, { buffer = float.buf, silent = true, desc = 'Filter by method' })

        -- Position cursor on first route
        if #formatted_routes > 0 then
            vim.api.nvim_win_set_cursor(float.win, { 3, 1 })
        end
    end)
end

-- Show filtered routes
function M.show_filtered_routes(filter)
    get_routes(function(all_routes)
        local filtered_routes = {}
        for _, route in ipairs(all_routes) do
            local uri = ''
            if route.uri and type(route.uri) == 'string' then
                uri = route.uri
            elseif route.url and type(route.url) == 'string' then
                uri = route.url
            end

            if uri:lower():match(filter:lower()) then
                table.insert(filtered_routes, route)
            end
        end

        if #filtered_routes == 0 then
            ui.warn('No routes found matching: ' .. filter)
            return
        end

        -- Use the same display logic but with filtered routes
        local temp_cache = routes_cache.data
        routes_cache.data = filtered_routes
        M.show_routes()
        routes_cache.data = temp_cache
    end)
end

-- Show routes by method
function M.show_routes_by_method(method)
    get_routes(function(all_routes)
        local filtered_routes = {}
        for _, route in ipairs(all_routes) do
            local methods = route.methods or route.method or {}
            if type(methods) == 'string' then
                methods = { methods }
            end

            for _, m in ipairs(methods) do
                if m:upper() == method:upper() then
                    table.insert(filtered_routes, route)
                    break
                end
            end
        end

        if #filtered_routes == 0 then
            ui.warn('No ' .. method .. ' routes found')
            return
        end

        -- Use the same display logic but with filtered routes
        local temp_cache = routes_cache.data
        routes_cache.data = filtered_routes
        M.show_routes()
        routes_cache.data = temp_cache
    end)
end

-- Navigate to route definition (same as before but with better error handling)
function M.navigate_to_route_definition(route)
    local root = _G.laravel_nvim.project_root
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
                local route_name = ''
                if route.name and type(route.name) == 'string' then
                    route_name = route.name
                end

                local route_uri = ''
                if route.uri and type(route.uri) == 'string' then
                    route_uri = route.uri
                elseif route.url and type(route.url) == 'string' then
                    route_uri = route.url
                end

                if route_name ~= '' then
                    -- Look for named routes
                    if line:match('->name%s*%(%s*[\'"]' .. vim.pesc(route_name) .. '[\'"]') then
                        vim.cmd('edit ' .. route_file)
                        vim.fn.cursor(i, 1)
                        vim.cmd('normal! zz')
                        return
                    end
                elseif route_uri ~= '' then
                    -- Look for URI pattern
                    if line:match('[\'"]' .. vim.pesc(route_uri) .. '[\'"]') then
                        vim.cmd('edit ' .. route_file)
                        vim.fn.cursor(i, 1)
                        vim.cmd('normal! zz')
                        return
                    end
                end
            end
        end
    end

    -- If not found in route files, try to navigate to controller
    if route.action then
        local controller = route.action:match('([^@\\]+)@')
        if controller then
            require('laravel.navigate').goto_controller(controller:match('[^\\]+$'))
            return
        end
    end

    ui.warn('Route definition not found')
end

-- Find route by current line in route files
function M.find_route_at_cursor()
    local current_file = vim.fn.expand('%:p')
    local root = _G.laravel_nvim.project_root

    if not root then return nil end

    -- Check if we're in a route file
    local routes_dir = root .. '/routes/'
    if not current_file:find(routes_dir, 1, true) then
        return nil
    end

    -- Get current line
    local line = vim.fn.getline('.')
    local line_num = vim.fn.line('.')

    -- Try to extract route information
    local uri = line:match('[\'"]([^\'"%s]+)[\'"]')
    local name = line:match('->name%s*%(%s*[\'"]([^\'\"]+)[\'"]')
    local method = line:match('Route::(%w+)')

    if uri then
        return {
            uri = uri,
            name = name,
            method = method,
            line = line_num,
            file = current_file,
        }
    end

    return nil
end

-- Test route (placeholder for future implementation)
function M.test_route()
    local route_info = M.find_route_at_cursor()
    if not route_info then
        ui.warn('No route found at cursor')
        return
    end

    ui.info('Route testing: ' .. (route_info.uri or 'unknown') .. ' (feature coming soon!)')
end

-- Clear routes cache
function M.clear_cache()
    routes_cache = {}
    cache_timestamp = 0
end

-- Setup function
function M.setup()
    -- Add route-specific keymaps in route files
    vim.api.nvim_create_autocmd({ 'BufRead', 'BufNewFile' }, {
        pattern = '*/routes/*.php',
        callback = function()
            vim.keymap.set('n', '<leader>rt', M.test_route, {
                buffer = true,
                desc = 'Test route at cursor'
            })

            vim.keymap.set('n', 'gd', function()
                local route_info = M.find_route_at_cursor()
                if route_info and route_info.name then
                    get_routes(function(routes)
                        for _, route in ipairs(routes) do
                            if route.name == route_info.name then
                                M.navigate_to_route_definition(route)
                                return
                            end
                        end
                        ui.warn('Route definition not found')
                    end)
                else
                    -- Fallback to LSP definition if available
                    if vim.lsp.buf.definition then
                        vim.lsp.buf.definition()
                    else
                        ui.warn('No route or LSP definition found')
                    end
                end
            end, {
                buffer = true,
                desc = 'Go to route definition or LSP definition'
            })
        end,
    })
end

return M
