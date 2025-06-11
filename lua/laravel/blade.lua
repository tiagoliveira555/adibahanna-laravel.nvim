-- Laravel Blade template support
local M = {}



-- Setup Blade file type
local function setup_blade_filetype()
    -- Set up Blade file detection
    vim.api.nvim_create_autocmd({ 'BufRead', 'BufNewFile' }, {
        pattern = '*.blade.php',
        callback = function()
            vim.bo.filetype = 'blade'
        end,
    })

    -- Set up syntax for Blade files
    vim.api.nvim_create_autocmd('FileType', {
        pattern = 'blade',
        callback = function()
            -- Set basic PHP-like settings
            vim.bo.commentstring = '{{-- %s --}}'
            vim.bo.comments = 's:{{--,e:--}}'

            -- Set up some basic syntax highlighting
            vim.cmd([[
        syntax clear
        runtime! syntax/html.vim
        runtime! syntax/php.vim

        " Blade directives
        syntax match bladeDirective /@\w\+/
        syntax region bladeEcho start=/{{/ end=/}}/ contains=phpRegion
        syntax region bladeEchoRaw start=/{!!/ end=/!!}/ contains=phpRegion
        syntax region bladeComment start=/{{--/ end=/--}}/

        " Highlight groups
        highlight link bladeDirective Special
        highlight link bladeEcho Identifier
        highlight link bladeEchoRaw Identifier
        highlight link bladeComment Comment
      ]])
        end,
    })
end



-- Setup Blade indentation
local function setup_blade_indentation()
    vim.api.nvim_create_autocmd('FileType', {
        pattern = 'blade',
        callback = function()
            -- Set indentation rules similar to HTML/PHP
            vim.bo.shiftwidth = 4
            vim.bo.tabstop = 4
            vim.bo.softtabstop = 4
            vim.bo.expandtab = true
            vim.bo.autoindent = true
            vim.bo.smartindent = true
        end,
    })
end

-- Find view files
function M.find_views()
    local root = _G.laravel_nvim.project_root
    if not root then return {} end

    local views_path = root .. '/resources/views'
    if vim.fn.isdirectory(views_path) == 0 then
        return {}
    end

    local views = {}
    local function scan_directory(dir, prefix)
        prefix = prefix or ''
        local items = vim.fn.readdir(dir)

        for _, item in ipairs(items) do
            local full_path = dir .. '/' .. item
            local view_name = prefix .. (prefix ~= '' and '.' or '') .. item

            if vim.fn.isdirectory(full_path) == 1 then
                -- Recursively scan subdirectories
                local subviews = scan_directory(full_path, view_name)
                for _, subview in ipairs(subviews) do
                    views[#views + 1] = subview
                end
            elseif item:match('%.blade%.php$') then
                -- Remove .blade.php extension for view name
                view_name = view_name:gsub('%.blade%.php$', '')
                views[#views + 1] = {
                    name = view_name,
                    path = full_path,
                }
            end
        end
    end

    scan_directory(views_path)
    return views
end

-- Get view name from current buffer
function M.get_current_view_name()
    local current_file = vim.fn.expand('%:p')
    local root = _G.laravel_nvim.project_root

    if not root or not current_file:match('%.blade%.php$') then
        return nil
    end

    local views_path = root .. '/resources/views/'
    if not current_file:find(views_path, 1, true) then
        return nil
    end

    -- Extract view name
    local relative_path = current_file:sub(#views_path + 1)
    local view_name = relative_path:gsub('%.blade%.php$', ''):gsub('/', '.')

    return view_name
end

-- Navigate to view
function M.goto_view(view_name)
    if not view_name or view_name == '' then
        -- Show view picker
        local views = M.find_views()
        if #views == 0 then
            vim.notify('No Blade views found', vim.log.levels.WARN)
            return
        end

        local items = {}
        for _, view in ipairs(views) do
            items[#items + 1] = view.name
        end

        require('laravel.ui').select(items, {
            prompt = 'Select view:',
            kind = 'blade_view',
        }, function(choice)
            if choice then
                for _, view in ipairs(views) do
                    if view.name == choice then
                        vim.cmd('edit ' .. view.path)
                        break
                    end
                end
            end
        end)
    else
        -- Convert dot notation to file path
        local root = _G.laravel_nvim.project_root
        if not root then return end

        local file_path = root .. '/resources/views/' .. view_name:gsub('%.', '/') .. '.blade.php'
        if vim.fn.filereadable(file_path) == 1 then
            vim.cmd('edit ' .. file_path)
        else
            vim.notify('View not found: ' .. view_name, vim.log.levels.ERROR)
        end
    end
end

-- Setup function
function M.setup()
    setup_blade_filetype()
    setup_blade_indentation()
end

return M
