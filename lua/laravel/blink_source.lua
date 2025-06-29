-- Laravel completion source for blink.nvim
local M = {}

local completions = require('laravel.completions')

-- Detect Laravel helper functions and their context
local function get_completion_context(line, col)
    -- First, try to extract complete Laravel function calls from the entire line
    local function extract_laravel_call(line, func_name)
        -- Pattern to match: func_name('string') or func_name("string")
        local pattern = func_name .. "%s*%(%s*['\"]([^'\"]*)['\"]"
        local match = line:match(pattern)
        return match
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
                    start_col = func_start
                }
            end
        end
    end

    -- Check for facade method calls: FacadeName::methodName
    local before_cursor = line:sub(1, col)
    local facade_pattern = "([%w_]+)::[%w_]*$"
    local facade_match = before_cursor:match(facade_pattern)
    if facade_match then
        return {
            func = 'facade',
            partial = facade_match,
            start_col = col - #facade_match + 1
        }
    end

    -- Check for fluent migration methods: $table->methodName
    local fluent_pattern = "%$[%w_]*%s*%->[%w_]*$"
    if before_cursor:match(fluent_pattern) then
        return {
            func = 'fluent',
            partial = '',
            start_col = col
        }
    end

    -- Fallback: use the old method for partial matches during typing
    local patterns = {
        { pattern = "route%s*%(%s*['\"]([^'\"]*)",           func = 'route' },
        { pattern = "view%s*%(%s*['\"]([^'\"]*)",            func = 'view' },
        { pattern = "config%s*%(%s*['\"]([^'\"]*)",          func = 'config' },
        { pattern = "__%s*%(%s*['\"]([^'\"]*)",              func = '__' },
        { pattern = "trans%s*%(%s*['\"]([^'\"]*)",           func = 'trans' },
        { pattern = "env%s*%(%s*['\"]([^'\"]*)",             func = 'env' },
        { pattern = "app%s*%(%s*['\"]([^'\"]*)",             func = 'app' },
        { pattern = "resolve%s*%(%s*['\"]([^'\"]*)",         func = 'app' },
        { pattern = "Inertia::render%s*%(%s*['\"]([^'\"]*)", func = 'view' },
        { pattern = "inertia%s*%(%s*['\"]([^'\"]*)",         func = 'view' },
    }

    for _, p in ipairs(patterns) do
        local match = before_cursor:match(p.pattern)
        if match then
            return {
                func = p.func,
                partial = match,
                start_col = col - #match + 1
            }
        end
    end

    return nil
end

-- Create the source class
local Source = {}
Source.__index = Source

function Source.new()
    return setmetatable({}, Source)
end

function Source:get_completions(context, callback)
    -- Only trigger in Laravel projects
    if not (_G.laravel_nvim and _G.laravel_nvim.is_laravel_project) then
        callback({ is_incomplete_forward = false, is_incomplete_backward = false, items = {} })
        return
    end

    local line = context.line
    local col = context.cursor[2]

    local completion_context = get_completion_context(line, col)
    if not completion_context then
        callback({ is_incomplete_forward = false, is_incomplete_backward = false, items = {} })
        return
    end

    -- Get completions from our system
    local ok, result = pcall(function()
        local items = {}
        local completions_list = completions.get_completions(completion_context.func, completion_context.partial)

        for i, completion in ipairs(completions_list) do
            -- Give env completions highest priority within Laravel completions
            local sort_prefix = completion_context.func == 'env' and '0000' or '0001'

            -- Get the correct kind value for blink.cmp
            local kind = 1 -- Default to Text kind
            local ok, types = pcall(require, 'blink.cmp.types')
            if ok and types.CompletionItemKind then
                kind = types.CompletionItemKind.Text or 1
            end

            table.insert(items, {
                label = completion,
                kind = kind,
                detail = 'Laravel ' .. completion_context.func .. '()',
                documentation = {
                    kind = 'markdown',
                    value = '**Laravel Helper**: `' .. completion_context.func .. '("' .. completion .. '")`'
                },
                insertText = completion,
                filterText = completion,
                sortText = string.format('%s_%04d_%s', sort_prefix, i, completion), -- All Laravel completions first
                score_offset = 2000,                                                -- Maximum priority for all Laravel completions
            })
        end

        return {
            is_incomplete_forward = false,
            is_incomplete_backward = false,
            items = items
        }
    end)

    if ok then
        callback(result)
    else
        -- Only show error in debug mode to avoid annoying notifications on hover
        if vim.g.laravel_nvim_debug then
            vim.notify('Laravel completion error: ' .. tostring(result), vim.log.levels.ERROR)
        end
        callback({ is_incomplete_forward = false, is_incomplete_backward = false, items = {} })
    end
end

function Source:resolve(item, callback)
    callback(item)
end

function Source:get_trigger_characters()
    return { "'", '"', ':', '>' }
end

-- Export the Source class for blink.nvim to instantiate
M.new = Source.new

-- Setup function
function M.setup()
    -- Only setup if we're in a Laravel project
    if not (_G.laravel_nvim and _G.laravel_nvim.is_laravel_project) then
        return
    end

    local ok, blink = pcall(require, 'blink.cmp')
    if not ok then
        -- Fallback to omnifunc
        vim.api.nvim_create_autocmd('FileType', {
            pattern = { 'php', 'blade' },
            callback = function()
                vim.bo.omnifunc = 'v:lua.require("laravel.completion_source").omnifunc'
            end,
        })
    end
end

return M
