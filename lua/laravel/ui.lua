-- UI utilities for Laravel.nvim
local M = {}

-- Enhanced vim.ui.select wrapper with better formatting
function M.select(items, opts, on_choice)
    opts = opts or {}

    -- Format items if they are tables
    local formatted_items = {}
    local item_map = {}

    for i, item in ipairs(items) do
        local display_item
        if type(item) == 'table' then
            display_item = item.name or item.label or tostring(item)
            item_map[display_item] = item
        else
            display_item = tostring(item)
            item_map[display_item] = item
        end
        formatted_items[i] = display_item
    end

    -- For now, use vim.ui.select (snacks.nvim integration needs proper API research)
    vim.ui.select(formatted_items, {
        prompt = opts.prompt or 'Select item:',
        format_item = function(item)
            return item
        end,
    }, function(choice)
        if choice and on_choice then
            on_choice(item_map[choice])
        end
    end)
end

-- TODO: Implement proper snacks.nvim integration
-- For now, we're using vim.ui.select for compatibility

-- Input dialog with validation
function M.input(opts, on_confirm)
    opts = opts or {}

    vim.ui.input({
        prompt = opts.prompt or 'Enter value: ',
        default = opts.default,
        completion = opts.completion,
    }, function(input)
        if input then
            -- Validate input if validator provided
            if opts.validate then
                local is_valid, error_msg = opts.validate(input)
                if not is_valid then
                    vim.notify(error_msg or 'Invalid input', vim.log.levels.ERROR)
                    return
                end
            end

            if on_confirm then
                on_confirm(input)
            end
        end
    end)
end

-- Show notification with proper formatting
function M.notify(message, level, opts)
    level = level or vim.log.levels.INFO
    opts = opts or {}

    -- For now, use vim.notify (snacks.nvim integration needs proper API research)
    vim.notify(message, level, {
        title = opts.title or 'Laravel.nvim',
        timeout = opts.timeout,
    })
end

-- Show info message
function M.info(message, opts)
    M.notify(message, vim.log.levels.INFO, opts)
end

-- Show warning message
function M.warn(message, opts)
    M.notify(message, vim.log.levels.WARN, opts)
end

-- Show error message
function M.error(message, opts)
    M.notify(message, vim.log.levels.ERROR, opts)
end

-- Create a floating window
function M.create_float(opts)
    opts = opts or {}

    local width = opts.width or math.floor(vim.o.columns * 0.8)
    local height = opts.height or math.floor(vim.o.lines * 0.8)

    -- Calculate position
    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)

    -- Create buffer
    local buf = vim.api.nvim_create_buf(false, true)

    -- Set buffer options
    vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
    vim.api.nvim_buf_set_option(buf, 'filetype', opts.filetype or 'text')

    -- Create window
    local win = vim.api.nvim_open_win(buf, true, {
        relative = 'editor',
        width = width,
        height = height,
        row = row,
        col = col,
        style = 'minimal',
        border = opts.border or 'rounded',
        title = opts.title,
        title_pos = 'center',
    })

    -- Set window options
    vim.api.nvim_win_set_option(win, 'winhl', 'Normal:Normal,FloatBorder:FloatBorder')

    -- Set content if provided
    if opts.content then
        local lines = type(opts.content) == 'table' and opts.content or { opts.content }
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    end

    -- Set up keymaps for closing
    local function close()
        if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_close(win, true)
        end
    end

    vim.keymap.set('n', 'q', close, { buffer = buf, silent = true })
    vim.keymap.set('n', '<Esc>', close, { buffer = buf, silent = true })

    return {
        buf = buf,
        win = win,
        close = close,
    }
end

-- Show content in a floating window
function M.show_float(content, opts)
    opts = opts or {}
    opts.content = content

    return M.create_float(opts)
end

return M
