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

-- Format route for display
local function format_route(route)
    local methods = table.concat(route.methods or {}, '|')
    local uri = route.uri or ''
    local name = route.name or ''
    local action = route.action or ''

    -- Extract controller and method from action
    local controller, method = action:match('([^@]+)@([^@]+)')
    if not controller then
        controller = action
        method = ''
    end

    return {
        display = string.format('%-8s %-30s %-20s %s', methods, uri, name, controller),
        route = route,
        methods = methods,
        uri = uri,
        name = name,
        controller = controller,
        method = method,
    }
end

-- Show routes in a floating window
function M.show_routes()
    get_routes(function(routes)
        if not routes or #routes == 0 then
            ui.warn('No routes found')
            return
        end

        -- Format routes
        local formatted_routes = {}
        local content_lines = {}

        -- Header
        table.insert(content_lines, string.format('%-8s %-30s %-20s %s', 'METHOD', 'URI', 'NAME', 'ACTION'))
        table.insert(content_lines, string.rep('-', 80))

        for _, route in ipairs(routes) do
            local formatted = format_route(route)
            table.insert(formatted_routes, formatted)
            table.insert(content_lines, formatted.display)
        end

        -- Show in floating window
        local float = ui.show_float(content_lines, {
            title = 'Laravel Routes',
            filetype = 'laravel-routes',
            width = math.min(120, vim.o.columns - 4),
            height = math.min(#content_lines + 3, vim.o.lines - 6),
        })

        -- Set up navigation keymaps
        vim.keymap.set('n', '<CR>', function()
            local line_num = vim.fn.line('.') - 2 -- Account for header
            if line_num > 0 and line_num <= #formatted_routes then
                local selected_route = formatted_routes[line_num]
                if selected_route.controller and selected_route.controller ~= '' then
                    -- Try to navigate to controller
                    require('laravel.navigate').goto_controller(selected_route.controller:match('[^\\]+$'))
                end
            end
            float.close()
        end, { buffer = float.buf, silent = true })

        vim.keymap.set('n', 'r', function()
            -- Refresh routes
            M.clear_cache()
            float.close()
            M.show_routes()
        end, { buffer = float.buf, silent = true })

        -- Add syntax highlighting for routes
        vim.cmd([[
      syntax match LaravelRouteMethod /^\w\+/
      syntax match LaravelRouteUri /\s\+\/\S*/
      syntax match LaravelRouteName /\s\+\w\+\.\w\+/

      highlight link LaravelRouteMethod Keyword
      highlight link LaravelRouteUri String
      highlight link LaravelRouteName Identifier
    ]])
    end)
end

-- Navigate to route definition
function M.goto_route(route_name)
    if not route_name or route_name == '' then
        -- Show route picker based on names
        get_routes(function(routes)
            local named_routes = {}
            for _, route in ipairs(routes) do
                if route.name and route.name ~= '' then
                    named_routes[#named_routes + 1] = {
                        name = route.name,
                        route = route,
                    }
                end
            end

            if #named_routes == 0 then
                ui.warn('No named routes found')
                return
            end

            local items = {}
            for _, named_route in ipairs(named_routes) do
                items[#items + 1] = named_route.name
            end

            ui.select(items, {
                prompt = 'Select route:',
                kind = 'laravel_route',
            }, function(choice)
                if choice then
                    for _, named_route in ipairs(named_routes) do
                        if named_route.name == choice then
                            M.navigate_to_route_definition(named_route.route)
                            break
                        end
                    end
                end
            end)
        end)
    else
        -- Find specific route
        get_routes(function(routes)
            local found_route = nil
            for _, route in ipairs(routes) do
                if route.name == route_name then
                    found_route = route
                    break
                end
            end

            if found_route then
                M.navigate_to_route_definition(found_route)
            else
                ui.error('Route not found: ' .. route_name)
            end
        end)
    end
end

-- Navigate to where a route is defined
function M.navigate_to_route_definition(route)
    local root = _G.laravel_nvim.project_root
    if not root then
        ui.error('Not in a Laravel project')
        return
    end

    -- Check web routes first
    local web_routes = root .. '/routes/web.php'
    if vim.fn.filereadable(web_routes) == 1 then
        local lines = vim.fn.readfile(web_routes)
        for i, line in ipairs(lines) do
            if route.name and route.name ~= '' then
                -- Look for named routes
                if line:match('->name%s*%(%s*[\'"]' .. vim.pesc(route.name) .. '[\'"]') then
                    vim.cmd('edit ' .. web_routes)
                    vim.fn.cursor(i, 1)
                    return
                end
            elseif route.uri then
                -- Look for URI pattern
                if line:match('[\'"]' .. vim.pesc(route.uri) .. '[\'"]') then
                    vim.cmd('edit ' .. web_routes)
                    vim.fn.cursor(i, 1)
                    return
                end
            end
        end
    end

    -- Check API routes
    local api_routes = root .. '/routes/api.php'
    if vim.fn.filereadable(api_routes) == 1 then
        local lines = vim.fn.readfile(api_routes)
        for i, line in ipairs(lines) do
            if route.name and route.name ~= '' then
                if line:match('->name%s*%(%s*[\'"]' .. vim.pesc(route.name) .. '[\'"]') then
                    vim.cmd('edit ' .. api_routes)
                    vim.fn.cursor(i, 1)
                    return
                end
            elseif route.uri then
                if line:match('[\'"]' .. vim.pesc(route.uri) .. '[\'"]') then
                    vim.cmd('edit ' .. api_routes)
                    vim.fn.cursor(i, 1)
                    return
                end
            end
        end
    end

    -- If not found in route files, try to navigate to controller
    if route.action then
        local controller = route.action:match('([^@]+)@')
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

-- Test route (if testing tools are available)
function M.test_route()
    local route_info = M.find_route_at_cursor()
    if not route_info then
        ui.warn('No route found at cursor')
        return
    end

    -- This is a placeholder for route testing functionality
    ui.info('Route testing not yet implemented for: ' .. (route_info.uri or 'unknown'))
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
                    M.goto_route(route_info.name)
                else
                    vim.lsp.buf.definition()
                end
            end, {
                buffer = true,
                desc = 'Go to route definition or LSP definition'
            })
        end,
    })
end

return M
