-- Laravel application architecture analysis and diagram generation
local ui = require('laravel.ui')

local M = {}

-- Get project root directory
local function get_project_root()
    local current_dir = vim.fn.getcwd()
    local artisan_file = current_dir .. '/artisan'

    if vim.fn.filereadable(artisan_file) == 1 then
        return current_dir
    end

    -- Try to find Laravel root by looking for artisan file
    local root = vim.fn.findfile('artisan', vim.fn.expand('%:p:h') .. ';')
    if root and root ~= '' then
        return vim.fn.fnamemodify(root, ':h')
    end

    return nil
end

-- Parse routes to understand application flow
function M.analyze_routes()
    local routes = {}
    local root = get_project_root()
    if not root then return routes end

    local routes_dir = root .. '/routes'
    if vim.fn.isdirectory(routes_dir) == 0 then return routes end

    local route_files = vim.fn.glob(routes_dir .. '/*.php', false, true)

    for _, file in ipairs(route_files) do
        local content = vim.fn.readfile(file)
        local file_name = vim.fn.fnamemodify(file, ':t:r')

        for _, line in ipairs(content) do
            line = line:match('^%s*(.-)%s*$') or line

            -- Parse different route patterns
            local patterns = {
                -- Route::get('/users', [UserController::class, 'index'])
                "Route::(%w+)%s*%(%s*['\"]([^'\"]+)['\"]%s*,%s*%[([%w\\]+)::class%s*,%s*['\"]([^'\"]+)['\"]%]",
                -- Route::get('/users', 'UserController@index')
                "Route::(%w+)%s*%(%s*['\"]([^'\"]+)['\"]%s*,%s*['\"]([^'\"@]+)@([^'\"]+)['\"]",
                -- Route::resource('users', UserController::class)
                "Route::resource%s*%(%s*['\"]([^'\"]+)['\"]%s*,%s*([%w\\]+)::class",
            }

            for _, pattern in ipairs(patterns) do
                local success, matches = pcall(function()
                    return { line:match(pattern) }
                end)

                if success and #matches > 0 then
                    if #matches == 4 then
                        -- Standard route: method, path, controller, action
                        table.insert(routes, {
                            method = matches[1]:upper(),
                            path = matches[2],
                            controller = matches[3]:match('([^\\]+)$') or matches[3],
                            action = matches[4],
                            file = file_name,
                            type = 'standard'
                        })
                    elseif #matches == 2 and pattern:match('resource') then
                        -- Resource route
                        local resource_name = matches[1]
                        local controller = matches[2]:match('([^\\]+)$') or matches[2]

                        -- Add standard resource actions
                        local resource_actions = {
                            { method = 'GET',    action = 'index',   path = '/' .. resource_name },
                            { method = 'GET',    action = 'create',  path = '/' .. resource_name .. '/create' },
                            { method = 'POST',   action = 'store',   path = '/' .. resource_name },
                            { method = 'GET',    action = 'show',    path = '/' .. resource_name .. '/{id}' },
                            { method = 'GET',    action = 'edit',    path = '/' .. resource_name .. '/{id}/edit' },
                            { method = 'PUT',    action = 'update',  path = '/' .. resource_name .. '/{id}' },
                            { method = 'DELETE', action = 'destroy', path = '/' .. resource_name .. '/{id}' },
                        }

                        for _, res_action in ipairs(resource_actions) do
                            table.insert(routes, {
                                method = res_action.method,
                                path = res_action.path,
                                controller = controller,
                                action = res_action.action,
                                file = file_name,
                                type = 'resource'
                            })
                        end
                    end
                    break
                end
            end
        end
    end

    return routes
end

-- Analyze controllers and their dependencies
function M.analyze_controllers()
    local controllers = {}
    local root = get_project_root()
    if not root then return controllers end

    local controllers_dir = root .. '/app/Http/Controllers'
    if vim.fn.isdirectory(controllers_dir) == 0 then return controllers end

    local controller_files = vim.fn.glob(controllers_dir .. '/**/*.php', false, true)

    for _, file in ipairs(controller_files) do
        local content = vim.fn.readfile(file)
        local controller_name = vim.fn.fnamemodify(file, ':t:r')

        local controller_info = {
            name = controller_name,
            path = file,
            models = {},
            services = {},
            views = {},
            methods = {},
            uses = {}
        }

        for _, line in ipairs(content) do
            line = line:match('^%s*(.-)%s*$') or line

            -- Parse use statements
            local use_match = line:match('^use%s+([^;]+);')
            if use_match then
                table.insert(controller_info.uses, use_match)
            end

            -- Parse method definitions
            local method_match = line:match('public%s+function%s+(%w+)%s*%(')
            if method_match then
                table.insert(controller_info.methods, method_match)
            end

            -- Parse model usage
            local model_patterns = {
                "([%w]+)::find",
                "([%w]+)::create",
                "([%w]+)::where",
                "([%w]+)::all",
                "new%s+([%w]+)%s*%(",
                "%$([%w]+)%s*=.*new%s+([%w]+)"
            }

            for _, pattern in ipairs(model_patterns) do
                local success, model_match = pcall(function()
                    return line:match(pattern)
                end)
                if success and model_match and not controller_info.models[model_match] then
                    controller_info.models[model_match] = true
                end
            end

            -- Parse view usage
            local view_patterns = {
                "view%s*%(%s*['\"]([^'\"]+)['\"]",
                "Inertia::render%s*%(%s*['\"]([^'\"]+)['\"]"
            }

            for _, pattern in ipairs(view_patterns) do
                local success, view_match = pcall(function()
                    return line:match(pattern)
                end)
                if success and view_match and not controller_info.views[view_match] then
                    controller_info.views[view_match] = true
                end
            end
        end

        -- Convert sets to arrays
        local models_array = {}
        for model, _ in pairs(controller_info.models) do
            table.insert(models_array, model)
        end
        controller_info.models = models_array

        local views_array = {}
        for view, _ in pairs(controller_info.views) do
            table.insert(views_array, view)
        end
        controller_info.views = views_array

        controllers[controller_name] = controller_info
    end

    return controllers
end

-- Analyze models and their relationships
function M.analyze_models()
    local models = {}
    local root = get_project_root()
    if not root then return models end

    -- Try both Laravel 8+ structure and older structure
    local models_dirs = {
        root .. '/app/Models',
        root .. '/app'
    }

    for _, models_dir in ipairs(models_dirs) do
        if vim.fn.isdirectory(models_dir) == 1 then
            local model_files = vim.fn.glob(models_dir .. '/*.php', false, true)

            for _, file in ipairs(model_files) do
                local content = vim.fn.readfile(file)
                local model_name = vim.fn.fnamemodify(file, ':t:r')

                -- Skip if not a model (basic heuristic)
                local is_model = false
                for _, line in ipairs(content) do
                    if line:match('extends.*Model') or line:match('use.*Model') then
                        is_model = true
                        break
                    end
                end

                if is_model then
                    local model_info = {
                        name = model_name,
                        path = file,
                        relationships = {},
                        attributes = {},
                        table = nil
                    }

                    for _, line in ipairs(content) do
                        line = line:match('^%s*(.-)%s*$') or line

                        -- Parse table name
                        local table_match = line:match('protected%s+%$table%s*=%s*[\'"]([^\'"]+)[\'"]')
                        if table_match then
                            model_info.table = table_match
                        end

                        -- Parse relationships
                        local relationship_patterns = {
                            { 'hasMany',       'function%s+(%w+)%s*%(%s*%).*return%s+%$this%->hasMany%s*%(%s*([%w\\:]+)' },
                            { 'belongsTo',     'function%s+(%w+)%s*%(%s*%).*return%s+%$this%->belongsTo%s*%(%s*([%w\\:]+)' },
                            { 'hasOne',        'function%s+(%w+)%s*%(%s*%).*return%s+%$this%->hasOne%s*%(%s*([%w\\:]+)' },
                            { 'belongsToMany', 'function%s+(%w+)%s*%(%s*%).*return%s+%$this%->belongsToMany%s*%(%s*([%w\\:]+)' }
                        }

                        for _, rel_pattern in ipairs(relationship_patterns) do
                            local rel_type = rel_pattern[1]
                            local pattern = rel_pattern[2]

                            local success, matches = pcall(function()
                                return { line:match(pattern) }
                            end)

                            if success and #matches >= 2 then
                                local method_name = matches[1]
                                local related_model = matches[2]:match('([^\\:]+)$') or matches[2]
                                related_model = related_model:gsub('::class', '')

                                table.insert(model_info.relationships, {
                                    type = rel_type,
                                    method = method_name,
                                    model = related_model
                                })
                            end
                        end
                    end

                    models[model_name] = model_info
                end
            end
        end
    end

    return models
end

-- Show architecture diagram
function M.show_architecture_diagram(diagram_type)
    if not diagram_type then
        -- Show picker for diagram type
        ui.select({ 'Application Flow', 'Model Relationships', 'Route Mapping' }, {
            prompt = 'Select architecture diagram type:',
        }, function(choice)
            if choice == 'Application Flow' then
                M.show_architecture_diagram('flow')
            elseif choice == 'Model Relationships' then
                M.show_architecture_diagram('relationships')
            elseif choice == 'Route Mapping' then
                M.show_architecture_diagram('routes')
            end
        end)
        return
    end

    ui.info('Generating ' .. diagram_type .. ' architecture diagram...')

    local diagram = ''
    if diagram_type == 'flow' then
        diagram = M.generate_flow_diagram()
    elseif diagram_type == 'relationships' then
        diagram = M.generate_relationship_diagram()
    elseif diagram_type == 'routes' then
        diagram = M.generate_route_controller_diagram()
    else
        ui.error('Unknown diagram type: ' .. diagram_type)
        return
    end

    -- Try to show with create_diagram, fallback to buffer
    local success, err = pcall(function()
        return create_diagram({
            content = diagram
        })
    end)

    if not success then
        -- Fallback: open in a new buffer
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(diagram, '\n'))
        vim.api.nvim_buf_set_option(buf, 'filetype', 'mermaid')
        vim.api.nvim_buf_set_name(buf, 'Laravel Architecture - ' .. diagram_type:gsub('^%l', string.upper))
        vim.cmd('split')
        vim.api.nvim_set_current_buf(buf)
        ui.info('Architecture diagram displayed in buffer')
    end
end

-- Generate detailed application flow diagram
function M.generate_flow_diagram()
    local routes = M.analyze_routes()
    local controllers = M.analyze_controllers()
    local navigate_module = require('laravel.navigate')
    local models_list = navigate_module.find_models()

    local lines = {}
    table.insert(lines, 'flowchart TD')
    table.insert(lines, '    %% Laravel Application Request Lifecycle')
    table.insert(lines, '')

    -- Request Entry Point
    table.insert(lines, '    Client[("👤 Client<br/>HTTP Request")]')
    table.insert(lines, '    WebServer["🌐 Web Server<br/>(Nginx/Apache)"]')
    table.insert(lines, '    PublicIndex["📄 public/index.php<br/>Entry Point"]')
    table.insert(lines, '')

    -- Bootstrap & Service Providers
    table.insert(lines, '    Bootstrap["⚡ Bootstrap<br/>Application"]')
    table.insert(lines, '    ServiceProviders["🔧 Service Providers<br/>Register & Boot"]')
    table.insert(lines, '    Kernel["🔐 HTTP Kernel<br/>Handle Request"]')
    table.insert(lines, '')

    -- Routing & Middleware
    table.insert(lines, '    Router["🛣️ Router<br/>Match Route"]')
    table.insert(lines, '    GlobalMiddleware["🔒 Global Middleware<br/>(CORS, Security)"]')
    table.insert(lines, '    RouteMiddleware["🛡️ Route Middleware<br/>(Auth, Throttle)"]')
    table.insert(lines, '')

    -- Request Processing
    table.insert(lines, '    FormRequest["📝 Form Request<br/>Validation"]')
    table.insert(lines, '    Authorization["🔑 Authorization<br/>Policies & Gates"]')
    table.insert(lines, '')

    -- Controllers (detailed)
    local controller_nodes = {}
    local controller_methods = {}
    for controller_name, controller_info in pairs(controllers) do
        if #controller_info.methods > 0 then
            local node_id = 'C_' .. controller_name:gsub('[^%w]', '_')
            table.insert(lines,
                '    ' ..
                node_id ..
                '["🎮 ' .. controller_name .. '<br/>Methods: ' .. table.concat(controller_info.methods, ', ') .. '"]')
            controller_nodes[controller_name] = node_id
            controller_methods[controller_name] = controller_info.methods
        end
    end

    table.insert(lines, '')

    -- Services & Business Logic
    table.insert(lines, '    Services["🔨 Services<br/>Business Logic"]')
    table.insert(lines, '    Events["📡 Events<br/>Event System"]')
    table.insert(lines, '    Jobs["⚙️ Jobs<br/>Queue Processing"]')
    table.insert(lines, '')

    -- Data Layer
    table.insert(lines, '    Models["📊 Eloquent Models<br/>ORM Layer"]')
    table.insert(lines, '    QueryBuilder["🔍 Query Builder<br/>Database Queries"]')
    table.insert(lines, '    Database[("🗄️ Database<br/>MySQL/PostgreSQL")]')
    table.insert(lines, '    Cache["💾 Cache<br/>(Redis/Memcached)"]')
    table.insert(lines, '')

    -- Response Generation
    table.insert(lines, '    ViewEngine["🎨 View Engine<br/>Blade Templates"]')
    table.insert(lines, '    APIResponse["📡 API Response<br/>JSON/XML"]')
    table.insert(lines, '    FileResponse["📁 File Response<br/>Downloads/Uploads"]')
    table.insert(lines, '    RedirectResponse["↩️ Redirect Response<br/>URL Redirects"]')
    table.insert(lines, '')

    -- Response Processing
    table.insert(lines, '    ResponseMiddleware["📤 Response Middleware<br/>Transform Response"]')
    table.insert(lines, '    FinalResponse["✅ HTTP Response<br/>Headers & Content"]')
    table.insert(lines, '')

    -- Request Flow Connections
    table.insert(lines, '    %% Request Lifecycle Flow')
    table.insert(lines, '    Client --> WebServer')
    table.insert(lines, '    WebServer --> PublicIndex')
    table.insert(lines, '    PublicIndex --> Bootstrap')
    table.insert(lines, '    Bootstrap --> ServiceProviders')
    table.insert(lines, '    ServiceProviders --> Kernel')
    table.insert(lines, '    Kernel --> Router')
    table.insert(lines, '    Router --> GlobalMiddleware')
    table.insert(lines, '    GlobalMiddleware --> RouteMiddleware')
    table.insert(lines, '    RouteMiddleware --> FormRequest')
    table.insert(lines, '    FormRequest --> Authorization')
    table.insert(lines, '')

    -- Controller Connections
    local connected_controllers = {}
    for _, route in ipairs(routes) do
        local controller_node = controller_nodes[route.controller]
        if controller_node and not connected_controllers[controller_node] then
            table.insert(lines, '    Authorization --> ' .. controller_node)
            connected_controllers[controller_node] = true
        end
    end

    table.insert(lines, '')

    -- Controller to Services and Models
    for controller_name, controller_node in pairs(controller_nodes) do
        local controller_info = controllers[controller_name]
        if controller_info then
            table.insert(lines, '    ' .. controller_node .. ' --> Services')

            -- Connect to specific models if they use them
            if #controller_info.models > 0 then
                table.insert(lines, '    ' .. controller_node .. ' --> Models')
            end

            -- Events and Jobs
            table.insert(lines, '    ' .. controller_node .. ' --> Events')
            table.insert(lines, '    ' .. controller_node .. ' --> Jobs')
        end
    end

    table.insert(lines, '')

    -- Data Flow
    table.insert(lines, '    %% Data Layer Flow')
    table.insert(lines, '    Services --> Models')
    table.insert(lines, '    Models --> QueryBuilder')
    table.insert(lines, '    QueryBuilder --> Database')
    table.insert(lines, '    Models --> Cache')
    table.insert(lines, '    QueryBuilder --> Cache')
    table.insert(lines, '')

    -- Response Generation Flow
    table.insert(lines, '    %% Response Generation')
    for controller_name, controller_node in pairs(controller_nodes) do
        local controller_info = controllers[controller_name]
        if controller_info and #controller_info.views > 0 then
            table.insert(lines, '    ' .. controller_node .. ' --> ViewEngine')
        end
        table.insert(lines, '    ' .. controller_node .. ' --> APIResponse')
        table.insert(lines, '    ' .. controller_node .. ' --> FileResponse')
        table.insert(lines, '    ' .. controller_node .. ' --> RedirectResponse')
    end

    table.insert(lines, '')

    -- Final Response Flow
    table.insert(lines, '    %% Final Response Flow')
    table.insert(lines, '    ViewEngine --> ResponseMiddleware')
    table.insert(lines, '    APIResponse --> ResponseMiddleware')
    table.insert(lines, '    FileResponse --> ResponseMiddleware')
    table.insert(lines, '    RedirectResponse --> ResponseMiddleware')
    table.insert(lines, '    ResponseMiddleware --> FinalResponse')
    table.insert(lines, '    FinalResponse --> WebServer')
    table.insert(lines, '    WebServer --> Client')
    table.insert(lines, '')

    -- Background Processing
    table.insert(lines, '    %% Background Processing')
    table.insert(lines, '    Jobs --> Database')
    table.insert(lines, '    Jobs --> Cache')
    table.insert(lines, '    Events --> Jobs')
    table.insert(lines, '')

    -- Add detailed styling
    table.insert(lines, '    %% Styling')
    table.insert(lines, '    classDef entry fill:#e3f2fd,stroke:#1976d2,stroke-width:2px')
    table.insert(lines, '    classDef routing fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px')
    table.insert(lines, '    classDef security fill:#fff3e0,stroke:#f57f17,stroke-width:2px')
    table.insert(lines, '    classDef controller fill:#e8f5e8,stroke:#388e3c,stroke-width:2px')
    table.insert(lines, '    classDef service fill:#fce4ec,stroke:#c2185b,stroke-width:2px')
    table.insert(lines, '    classDef data fill:#e0f2f1,stroke:#00796b,stroke-width:2px')
    table.insert(lines, '    classDef response fill:#fff8e1,stroke:#fbc02d,stroke-width:2px')
    table.insert(lines, '    classDef background fill:#f1f8e9,stroke:#689f38,stroke-width:2px')
    table.insert(lines, '')

    -- Apply styles
    table.insert(lines, '    class Client,WebServer,PublicIndex entry')
    table.insert(lines, '    class Bootstrap,ServiceProviders,Kernel,Router routing')
    table.insert(lines, '    class GlobalMiddleware,RouteMiddleware,FormRequest,Authorization security')

    for _, controller_node in pairs(controller_nodes) do
        table.insert(lines, '    class ' .. controller_node .. ' controller')
    end

    table.insert(lines, '    class Services,Events service')
    table.insert(lines, '    class Models,QueryBuilder,Database,Cache data')
    table.insert(lines,
        '    class ViewEngine,APIResponse,FileResponse,RedirectResponse,ResponseMiddleware,FinalResponse response')
    table.insert(lines, '    class Jobs background')

    return table.concat(lines, '\n')
end

-- Generate relationship diagram (using existing models analysis)
function M.generate_relationship_diagram()
    -- Use existing models analysis from navigate.lua
    local navigate_module = require('laravel.navigate')
    local models_module = require('laravel.models')
    local models_list = navigate_module.find_models()

    local lines = {}
    table.insert(lines, 'graph TD')
    table.insert(lines, '    %% Model Relationships')
    table.insert(lines, '')

    if #models_list == 0 then
        table.insert(lines, '    NoModels["No models found"]')
        return table.concat(lines, '\n')
    end

    for _, model in ipairs(models_list) do
        local node_id = 'M_' .. model.name:gsub('[^%w]', '_')
        table.insert(lines, '    ' .. node_id .. '["📊 ' .. model.name .. '"]')

        -- Try to analyze relationships using models module
        local model_info = models_module.analyze_model(model.path)
        if model_info and model_info.relationships then
            for _, rel in ipairs(model_info.relationships) do
                local related_node = 'M_' .. rel.related_model:gsub('[^%w]', '_')
                local relationship_label = rel.type .. ' (' .. rel.method .. ')'
                table.insert(lines, '    ' .. node_id .. ' --> ' .. related_node .. ' : "' .. relationship_label .. '"')
            end
        end
    end

    return table.concat(lines, '\n')
end

-- Generate route-controller mapping
function M.generate_route_controller_diagram()
    local routes = M.analyze_routes()

    local lines = {}
    table.insert(lines, 'graph LR')
    table.insert(lines, '    %% Route to Controller Mapping')
    table.insert(lines, '')

    -- Group routes by method
    local method_groups = {}
    for _, route in ipairs(routes) do
        if not method_groups[route.method] then
            method_groups[route.method] = {}
        end
        table.insert(method_groups[route.method], route)
    end

    local route_id = 1
    for method, method_routes in pairs(method_groups) do
        table.insert(lines, '    subgraph ' .. method .. '_Routes["' .. method .. ' Routes"]')

        for _, route in ipairs(method_routes) do
            local node_id = 'R' .. route_id
            local controller_id = 'C' .. route_id

            table.insert(lines, '        ' .. node_id .. '["' .. route.path .. '"]')
            table.insert(lines, '        ' .. controller_id .. '["' .. route.controller .. '@' .. route.action .. '"]')
            table.insert(lines, '        ' .. node_id .. ' --> ' .. controller_id)

            route_id = route_id + 1
        end

        table.insert(lines, '    end')
        table.insert(lines, '')
    end

    return table.concat(lines, '\n')
end

return M
