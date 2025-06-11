-- Laravel Blade template support
local M = {}

-- Blade directives and their completion patterns
local blade_directives = {
    -- Control structures
    { trigger = 'if',            body = '@if($1)\n\t$0\n@endif' },
    { trigger = 'elseif',        body = '@elseif($1)\n\t$0' },
    { trigger = 'else',          body = '@else\n\t$0' },
    { trigger = 'unless',        body = '@unless($1)\n\t$0\n@endunless' },
    { trigger = 'for',           body = '@for($1; $2; $3)\n\t$0\n@endfor' },
    { trigger = 'foreach',       body = '@foreach($1 as $2)\n\t$0\n@endforeach' },
    { trigger = 'forelse',       body = '@forelse($1 as $2)\n\t$0\n@empty\n\t$3\n@endforelse' },
    { trigger = 'while',         body = '@while($1)\n\t$0\n@endwhile' },
    { trigger = 'switch',        body = '@switch($1)\n\t@case($2)\n\t\t$0\n\t\t@break\n\t@default\n@endswitch' },
    { trigger = 'case',          body = '@case($1)\n\t$0\n\t@break' },

    -- Template inheritance
    { trigger = 'extends',       body = '@extends(\'$1\')' },
    { trigger = 'section',       body = '@section(\'$1\')\n\t$0\n@endsection' },
    { trigger = 'yield',         body = '@yield(\'$1\'${2:, \'$3\'})' },
    { trigger = 'parent',        body = '@parent' },
    { trigger = 'show',          body = '@show' },
    { trigger = 'stop',          body = '@stop' },
    { trigger = 'append',        body = '@append' },
    { trigger = 'overwrite',     body = '@overwrite' },

    -- Including views
    { trigger = 'include',       body = '@include(\'$1\'${2:, [\'$3\' => $4]})' },
    { trigger = 'includeIf',     body = '@includeIf($1, \'$2\'${3:, [\'$4\' => $5]})' },
    { trigger = 'includeWhen',   body = '@includeWhen($1, \'$2\'${3:, [\'$4\' => $5]})' },
    { trigger = 'includeUnless', body = '@includeUnless($1, \'$2\'${3:, [\'$4\' => $5]})' },
    { trigger = 'includeFirst',  body = '@includeFirst([\'$1\', \'$2\']${3:, [\'$4\' => $5]})' },

    -- Components
    { trigger = 'component',     body = '@component(\'$1\'${2:, [\'$3\' => $4]})\n\t$0\n@endcomponent' },
    { trigger = 'slot',          body = '@slot(\'$1\')\n\t$0\n@endslot' },

    -- Authentication
    { trigger = 'auth',          body = '@auth${1:(\'$2\')}\n\t$0\n@endauth' },
    { trigger = 'guest',         body = '@guest${1:(\'$2\')}\n\t$0\n@endguest' },
    { trigger = 'can',           body = '@can(\'$1\'${2:, $3})\n\t$0\n@endcan' },
    { trigger = 'cannot',        body = '@cannot(\'$1\'${2:, $3})\n\t$0\n@endcannot' },
    { trigger = 'canany',        body = '@canany([\'$1\'${2:, \'$3\'}]${4:, $5})\n\t$0\n@endcanany' },

    -- Environment
    { trigger = 'env',           body = '@env(\'$1\')\n\t$0\n@endenv' },
    { trigger = 'production',    body = '@production\n\t$0\n@endproduction' },

    -- Error handling
    { trigger = 'error',         body = '@error(\'$1\')\n\t$0\n@enderror' },

    -- CSRF
    { trigger = 'csrf',          body = '@csrf' },
    { trigger = 'method',        body = '@method(\'$1\')' },

    -- JSON
    { trigger = 'json',          body = '@json($1)' },

    -- Translations
    { trigger = 'lang',          body = '@lang(\'$1\')' },

    -- PHP blocks
    { trigger = 'php',           body = '@php\n\t$0\n@endphp' },

    -- Stacks and pushes
    { trigger = 'stack',         body = '@stack(\'$1\')' },
    { trigger = 'push',          body = '@push(\'$1\')\n\t$0\n@endpush' },
    { trigger = 'prepend',       body = '@prepend(\'$1\')\n\t$0\n@endprepend' },

    -- Assets
    { trigger = 'asset',         body = '{{ asset(\'$1\') }}' },
    { trigger = 'url',           body = '{{ url(\'$1\') }}' },
    { trigger = 'route',         body = '{{ route(\'$1\'${2:, [\'$3\' => $4]}) }}' },
    { trigger = 'action',        body = '{{ action(\'$1\'${2:, [\'$3\' => $4]}) }}' },

    -- Forms
    { trigger = 'old',           body = '{{ old(\'$1\'${2:, \'$3\'}) }}' },

    -- Comments
    { trigger = 'comment',       body = '{{-- $1 --}}' },
}

-- Common Laravel helper functions for Blade
local laravel_helpers = {
    'abort', 'abort_if', 'abort_unless', 'app', 'auth', 'back', 'bcrypt',
    'cache', 'collect', 'config', 'cookie', 'csrf_field', 'csrf_token',
    'dd', 'dump', 'env', 'event', 'factory', 'info', 'logger', 'method_field',
    'now', 'old', 'optional', 'policy', 'redirect', 'request', 'rescue',
    'resolve', 'response', 'route', 'session', 'tap', 'today', 'trans',
    'trans_choice', 'url', 'validator', 'view', 'with'
}

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

-- Setup Blade snippets
local function setup_blade_snippets()
    vim.api.nvim_create_autocmd('FileType', {
        pattern = 'blade',
        callback = function()
            -- Add Blade-specific snippets using buffer-local keymaps
            for _, snippet in ipairs(blade_directives) do
                local trigger = snippet.trigger
                local body = snippet.body

                -- Create buffer-local keymap that expands to snippet
                vim.keymap.set('i', trigger .. '<Tab>', function()
                    -- Remove the trigger text
                    local pos = vim.api.nvim_win_get_cursor(0)
                    local line = vim.api.nvim_get_current_line()
                    local before_cursor = line:sub(1, pos[2])
                    local after_cursor = line:sub(pos[2] + 1)

                    -- Check if the trigger is at the end of the line before cursor
                    if before_cursor:sub(- #trigger) == trigger then
                        local new_before = before_cursor:sub(1, - #trigger - 1)
                        local new_line = new_before .. after_cursor
                        vim.api.nvim_set_current_line(new_line)
                        vim.api.nvim_win_set_cursor(0, { pos[1], #new_before })

                        -- Expand the snippet
                        vim.snippet.expand(body)
                    else
                        -- Fallback: just insert tab
                        vim.api.nvim_feedkeys('\t', 'n', false)
                    end
                end, { buffer = 0, desc = 'Expand ' .. trigger .. ' snippet' })
            end
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
    setup_blade_snippets()
    setup_blade_indentation()
end

return M
