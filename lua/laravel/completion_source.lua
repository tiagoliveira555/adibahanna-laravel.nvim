-- Laravel completion source for nvim-cmp
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
        { name = 'Inertia::render', func = 'view' },
        { name = 'inertia',         func = 'view' },
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

    -- Fallback: use the old method for partial matches during typing
    local before_cursor = line:sub(1, col)
    local patterns = {
        { pattern = "route%s*%(%s*['\"]([^'\"]*)",           func = 'route' },
        { pattern = "view%s*%(%s*['\"]([^'\"]*)",            func = 'view' },
        { pattern = "config%s*%(%s*['\"]([^'\"]*)",          func = 'config' },
        { pattern = "__%s*%(%s*['\"]([^'\"]*)",              func = '__' },
        { pattern = "trans%s*%(%s*['\"]([^'\"]*)",           func = 'trans' },
        { pattern = "Inertia::render%s*%(%s*['\"]([^'\"]*)", func = 'view' },
        { pattern = "inertia%s*%(%s*['\"]([^'\"]*)",         func = 'view' },
    }

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
    return { "'", '"' }
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
                sortText = string.format('%04d_%s', i, completion), -- High priority sorting
                priority = 1000,                                    -- High priority
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
        vim.notify('Laravel completion error: ' .. tostring(result), vim.log.levels.ERROR)
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
