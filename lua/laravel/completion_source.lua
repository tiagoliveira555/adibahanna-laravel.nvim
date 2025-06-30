-- Laravel completion source for nvim-cmp
local M = {}

local completions = require('laravel.completions')

-- Detect Laravel helper functions and their context
local function get_completion_context(line, col)
    -- First, try to extract complete Laravel function calls from the entire line
    local function extract_laravel_call(line, func_name)
        -- Escape special characters in function name for pattern matching
        local escaped_func = func_name:gsub('([%(%)%[%]%*%+%-%?%^%$%%::])', '%%%1')

        -- Pattern to match: func_name('string') or func_name("string")
        -- More robust pattern that handles various whitespace and characters
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
        { name = 'route',           func = 'route' },
        { name = 'view',            func = 'view' },
        { name = 'config',          func = 'config' },
        { name = '__',              func = '__' },
        { name = 'trans',           func = 'trans' },
        { name = 'env',             func = 'env' },
        { name = 'Inertia::render', func = 'view' },
        { name = 'inertia',         func = 'view' },
        { name = 'Route::inertia',  func = 'view' },
        { name = 'app',             func = 'app' },
        { name = 'resolve',         func = 'app' },
    }

    -- Try to find a complete Laravel function call on this line
    for _, func_def in ipairs(laravel_functions) do
        local match = extract_laravel_call(line, func_def.name)
        if match then
            -- Check if cursor is within this function call
            local func_start = line:find(func_def.name .. "%s*%(")
            local func_end = line:find("%)", func_start or 1)

            if func_start and func_end and col >= func_start and col <= func_end then
                return {
                    func = func_def.func,
                    partial = match,
                    trigger_char = line:sub(col, col) -- Character at cursor
                }
            end
        end
    end

    -- Check for facade method calls: FacadeName::methodName
    local facade_pattern = "([%w_]+)::[%w_]*$"
    local facade_match = before_cursor:match(facade_pattern)
    if facade_match then
        return {
            func = 'facade',
            partial = facade_match,
            trigger_char = line:sub(col, col)
        }
    end

    -- Check for fluent migration methods: $table->methodName
    local fluent_pattern = "%$[%w_]*%s*%->[%w_]*$"
    if before_cursor:match(fluent_pattern) then
        return {
            func = 'fluent',
            partial = '',
            trigger_char = line:sub(col, col)
        }
    end

    -- Fallback: use the old method for partial matches during typing
    local before_cursor = line:sub(1, col)

    local patterns = {
        { pattern = "route%s*%(%s*['\"]([^'\"]*)",                                        func = 'route' },
        { pattern = "view%s*%(%s*['\"]([^'\"]*)",                                         func = 'view' },
        { pattern = "config%s*%(%s*['\"]([^'\"]*)",                                       func = 'config' },
        { pattern = "__%s*%(%s*['\"]([^'\"]*)",                                           func = '__' },
        { pattern = "trans%s*%(%s*['\"]([^'\"]*)",                                        func = 'trans' },
        { pattern = "env%s*%(%s*['\"]([^'\"]*)",                                          func = 'env' },
        { pattern = "app%s*%(%s*['\"]([^'\"]*)",                                          func = 'app' },
        { pattern = "resolve%s*%(%s*['\"]([^'\"]*)",                                      func = 'app' },
        { pattern = "Inertia%s*::%s*render%s*%(%s*['\"]([^'\"]*)",                        func = 'view' },
        { pattern = "inertia%s*%(%s*['\"]([^'\"]*)",                                      func = 'view' },
        { pattern = "Route%s*::%s*inertia%s*%(%s*['\"][^'\"]*['\"]%s*,%s*['\"]([^'\"]*)", func = 'view' },
    }

    -- For navigation, prioritize full line patterns to get complete strings
    -- regardless of cursor position
    local full_line_patterns = {
        { pattern = "route%s*%(%s*['\"]([^'\"]+)['\"]",                                        func = 'route' },
        { pattern = "view%s*%(%s*['\"]([^'\"]+)['\"]",                                         func = 'view' },
        { pattern = "config%s*%(%s*['\"]([^'\"]+)['\"]",                                       func = 'config' },
        { pattern = "__%s*%(%s*['\"]([^'\"]+)['\"]",                                           func = '__' },
        { pattern = "trans%s*%(%s*['\"]([^'\"]+)['\"]",                                        func = 'trans' },
        { pattern = "env%s*%(%s*['\"]([^'\"]+)['\"]",                                          func = 'env' },
        { pattern = "app%s*%(%s*['\"]([^'\"]+)['\"]",                                          func = 'app' },
        { pattern = "resolve%s*%(%s*['\"]([^'\"]+)['\"]",                                      func = 'app' },
        { pattern = "Inertia%s*::%s*render%s*%(%s*['\"]([^'\"]+)['\"]",                        func = 'view' },
        { pattern = "inertia%s*%(%s*['\"]([^'\"]+)['\"]",                                      func = 'view' },
        { pattern = "Route%s*::%s*inertia%s*%(%s*['\"][^'\"]*['\"]%s*,%s*['\"]([^'\"]+)['\"]", func = 'view' },
    }

    for _, p in ipairs(full_line_patterns) do
        local match = line:match(p.pattern)
        if match then
            return {
                func = p.func,
                partial = match,
                trigger_char = line:sub(col, col) -- Character at cursor
            }
        end
    end

    -- Fallback to before_cursor approach for completion scenarios
    for _, p in ipairs(patterns) do
        local match = before_cursor:match(p.pattern)
        if match then
            return {
                func = p.func,
                partial = match,
                trigger_char = before_cursor:sub(-1) -- Last character
            }
        end
    end

    return nil
end

-- Expose for external use
M.get_completion_context = get_completion_context

-- nvim-cmp source implementation
local source = {}

function source:get_trigger_characters()
    return { "'", '"', ':', '>' }
end

function source:get_keyword_pattern()
    -- Allow dots, slashes, and alphanumeric for Laravel keys
    return [[\k\+\.\k\+\|\k\+/\k\+\|\k\+]]
end

function source:is_available()
    -- Only available in Laravel projects
    return _G.laravel_nvim and _G.laravel_nvim.is_laravel_project
end

function source:complete(request, callback)
    local line = request.context.cursor_before_line
    local col = request.context.cursor.col

    local context = get_completion_context(line, col)
    if not context then
        callback({ items = {}, isIncomplete = false })
        return
    end

    -- Wrap in pcall for error handling
    local ok, result = pcall(function()
        local items = {}
        local completions_list = completions.get_completions(context.func, context.partial)

        for i, completion in ipairs(completions_list) do
            -- Give env completions highest priority within Laravel completions
            local sort_prefix = context.func == 'env' and '0000' or '0001'

            table.insert(items, {
                label = completion,
                kind = 1, -- Text kind, avoid requiring cmp here
                detail = 'Laravel ' .. context.func .. '()',
                documentation = {
                    kind = 'markdown',
                    value = '**Laravel Helper**: `' .. context.func .. '("' .. completion .. '")`'
                },
                insertText = completion,
                filterText = completion,
                sortText = string.format('%s_%04d_%s', sort_prefix, i, completion), -- All Laravel completions first
                priority = 2000,                                                    -- Maximum priority for all Laravel completions
            })
        end

        return {
            items = items,
            isIncomplete = false
        }
    end)

    if ok then
        callback(result)
    else
        -- Only show error in debug mode to avoid annoying notifications on hover
        if vim.g.laravel_nvim_debug then
            vim.notify('Laravel completion error: ' .. tostring(result), vim.log.levels.ERROR)
        end
        callback({ items = {}, isIncomplete = false })
    end
end

-- Register with nvim-cmp if available
function M.setup()
    local ok, cmp = pcall(require, 'cmp')
    if ok then
        cmp.register_source('laravel', source)

        -- Don't override existing cmp config, just register our source
        -- Users need to add { name = 'laravel' } to their cmp sources manually
        vim.notify('Laravel completions registered with nvim-cmp. Add { name = "laravel" } to your cmp sources.',
            vim.log.levels.INFO)
    else
        -- Fallback: manual completion using omnifunc
        vim.api.nvim_create_autocmd('FileType', {
            pattern = { 'php', 'blade' },
            callback = function()
                vim.bo.omnifunc = 'v:lua.require("laravel.completion_source").omnifunc'
                vim.notify('Laravel completions set up via omnifunc. Use <C-x><C-o> to trigger.', vim.log.levels.INFO)
            end,
        })
    end
end

-- Omnifunc fallback for when nvim-cmp is not available
function M.omnifunc(findstart, base)
    if findstart == 1 then
        local line = vim.fn.getline('.')
        local col = vim.fn.col('.') - 1

        local context = get_completion_context(line, col)
        if context then
            -- Find start of the string being completed
            local start = col - #context.partial
            return start
        end

        return -1
    else
        local line = vim.fn.getline('.')
        local col = vim.fn.col('.') - 1

        local context = get_completion_context(line, col)
        if context then
            return completions.get_completions(context.func, base)
        end

        return {}
    end
end

return M
