-- Laravel-specific keymaps and utilities
--
-- To disable all Laravel keymaps and create your own, use:
-- require('laravel').setup({ keymaps = false })
--
-- Then you can create custom keymaps using the available commands:
-- vim.keymap.set('n', '<your-key>', ':Artisan<CR>')
-- vim.keymap.set('n', '<your-key>', ':Composer<CR>')
-- vim.keymap.set('n', '<your-key>', function() require('laravel.navigate').goto_controller() end)
-- etc.
local M = {}
local livewire = require('laravel.livewire')

-- Setup Laravel-specific keymaps
-- All Laravel keymaps use <leader>L prefix for organization:
--
-- Global Laravel commands:
--   <leader>Lc - Go to controller
--   <leader>Lm - Go to model
--   <leader>Lv - Go to view
--   <leader>Lr - Go to route file
--   <leader>LR - Show routes
--   <leader>La - Run artisan command
--   <leader>Lk - Laravel make command
--   <leader>Ls - Show Laravel status
--   <leader>LS - Show schema diagram
--   <leader>LE - Export schema diagram
--   <leader>LA - Show architecture diagram
--
-- Laravel Sail commands:
--   <leader>Lsu - Sail up (start containers)
--   <leader>Lsd - Sail down (stop containers)
--   <leader>Lsr - Sail restart
--   <leader>Lst - Sail test
--   <leader>Lss - Sail status
--   <leader>Lsh - Sail shell
--   <leader>Lsl - Sail logs
--
-- Model-specific (in model files):
--   <leader>LR - Show model relationships
--   <leader>LA - Show model attributes
--
-- Migration-specific (in migration files):
--   <leader>Li - Show migration info
--   <leader>LM - Run migration command
--
local function setup_laravel_keymaps()
    -- Setup global Laravel keymaps for PHP files
    vim.api.nvim_create_autocmd('FileType', {
        pattern = 'php',
        callback = function()
            local bufnr = vim.api.nvim_get_current_buf()
            local bufopts = { noremap = true, silent = true, buffer = bufnr }

            -- Enhanced gd mapping for Laravel string navigation
            vim.keymap.set('n', 'gd', function()
                -- Get Laravel project root
                local project_root = _G.laravel_nvim and _G.laravel_nvim.project_root
                if not project_root then
                    -- Not a Laravel project: fallback to LSP definition or default gd
                    if vim.lsp.buf.definition then
                        vim.lsp.buf.definition()
                    else
                        vim.cmd('normal! gd')
                    end
                    return
                end

                local navigate = require('laravel.navigate')

                -- 1. Attempt Livewire navigation in views (@livewire / <livewire:...>)
                if livewire.is_livewire_context() then
                    -- Use pcall to prevent errors from breaking execution
                    if pcall(livewire.goto_livewire_definition) then
                        return
                    end
                end

                -- 2. Attempt Laravel string navigation
                --    Examples: route('name'), view('name'), Inertia::render('Component')
                if navigate.is_laravel_navigation_context() then
                    if pcall(navigate.goto_laravel_string) then
                        return
                    end
                end

                -- 3. Attempt direct Livewire class detection
                --    Useful for references like Route::get('/', HomePage::class)
                local word = vim.fn.expand('<cword>') -- get word under cursor
                for _, component in ipairs(livewire.find_livewire_components()) do
                    -- Match the class name exactly or partially
                    if component.class_name == word or component.class_name:match(word) then
                        vim.cmd('edit ' .. component.path)
                        return
                    end
                end

                -- 4. Fallback to LSP definition if nothing else matches
                if vim.lsp.buf.definition then
                    vim.lsp.buf.definition()
                else
                    -- Final fallback to built-in gd
                    vim.cmd('normal! gd')
                end
            end, vim.tbl_extend('force', bufopts, {
                desc = 'Laravel: Go to definition (Livewire directives, Laravel strings, Livewire classes, or LSP)'
            }))

            -- Laravel-specific navigation with <leader>L prefix
            vim.keymap.set('n', '<leader>Lc', function()
                require('laravel.navigate').goto_controller()
            end, vim.tbl_extend('force', bufopts, { desc = 'Laravel: Go to controller' }))

            vim.keymap.set('n', '<leader>Lm', function()
                require('laravel.navigate').goto_model()
            end, vim.tbl_extend('force', bufopts, { desc = 'Laravel: Go to model' }))

            vim.keymap.set('n', '<leader>Lv', function()
                require('laravel.navigate').goto_view()
            end, vim.tbl_extend('force', bufopts, { desc = 'Laravel: Go to view' }))

            vim.keymap.set('n', '<leader>LR', function()
                require('laravel.routes').show_routes()
            end, vim.tbl_extend('force', bufopts, { desc = 'Laravel: Show routes' }))

            vim.keymap.set('n', '<leader>Lr', function()
                require('laravel.navigate').goto_route_file()
            end, vim.tbl_extend('force', bufopts, { desc = 'Laravel: Go to route file' }))

            vim.keymap.set('n', '<leader>La', function()
                vim.cmd('Artisan')
            end, vim.tbl_extend('force', bufopts, { desc = 'Laravel: Run artisan command' }))

            vim.keymap.set('n', '<leader>Lk', function()
                require('laravel.artisan').make_command()
            end, vim.tbl_extend('force', bufopts, { desc = 'Laravel: Make command' }))

            vim.keymap.set('n', '<leader>Ls', function()
                vim.cmd('LaravelStatus')
            end, vim.tbl_extend('force', bufopts, { desc = 'Laravel: Show status' }))

            vim.keymap.set('n', '<leader>LS', function()
                require('laravel.schema').show_schema_diagram(false)
            end, vim.tbl_extend('force', bufopts, { desc = 'Laravel: Show schema diagram' }))

            vim.keymap.set('n', '<leader>LE', function()
                require('laravel.schema').show_schema_diagram(true)
            end, vim.tbl_extend('force', bufopts, { desc = 'Laravel: Export schema diagram' }))

            vim.keymap.set('n', '<leader>LA', function()
                require('laravel.architecture').show_architecture_diagram()
            end, vim.tbl_extend('force', bufopts, { desc = 'Laravel: Show architecture diagram' }))

            -- Livewire keymaps
            vim.keymap.set('n', '<leader>LC', function()
                livewire.goto_livewire_component()
            end, vim.tbl_extend('force', bufopts, { desc = 'Livewire: Go to component' }))

            vim.keymap.set('n', '<leader>LV', function()
                livewire.goto_livewire_view()
            end, vim.tbl_extend('force', bufopts, { desc = 'Livewire: Go to view' }))

            vim.keymap.set('n', '<leader>LT', function()
                livewire.toggle_livewire_file()
            end, vim.tbl_extend('force', bufopts, { desc = 'Livewire: Toggle between class and view' }))

            -- Laravel Sail keymaps
            vim.keymap.set('n', '<leader>Lsu', function()
                vim.cmd('SailUp')
            end, vim.tbl_extend('force', bufopts, { desc = 'Laravel Sail: Start containers' }))

            vim.keymap.set('n', '<leader>Lsd', function()
                vim.cmd('SailDown')
            end, vim.tbl_extend('force', bufopts, { desc = 'Laravel Sail: Stop containers' }))

            vim.keymap.set('n', '<leader>Lsr', function()
                vim.cmd('SailRestart')
            end, vim.tbl_extend('force', bufopts, { desc = 'Laravel Sail: Restart containers' }))

            vim.keymap.set('n', '<leader>Lst', function()
                vim.cmd('SailTest')
            end, vim.tbl_extend('force', bufopts, { desc = 'Laravel Sail: Run tests' }))

            vim.keymap.set('n', '<leader>Lss', function()
                vim.cmd('SailStatus')
            end, vim.tbl_extend('force', bufopts, { desc = 'Laravel Sail: Check status' }))

            vim.keymap.set('n', '<leader>Lsh', function()
                vim.cmd('SailShell')
            end, vim.tbl_extend('force', bufopts, { desc = 'Laravel Sail: Open shell' }))

            vim.keymap.set('n', '<leader>Lsl', function()
                vim.cmd('SailLogs')
            end, vim.tbl_extend('force', bufopts, { desc = 'Laravel Sail: View logs' }))

            vim.keymap.set('n', '<leader>Lso', function()
                vim.cmd('SailOpen')
            end, vim.tbl_extend('force', bufopts, { desc = 'Laravel Sail: Open in browser' }))

            -- Laravel Dump Viewer keymaps
            vim.keymap.set('n', '<leader>Ld', function()
                require('laravel.dump').open()
            end, vim.tbl_extend('force', bufopts, { desc = 'Laravel: Open dump viewer' }))

            vim.keymap.set('n', '<leader>LDi', function()
                require('laravel.dump').install()
            end, vim.tbl_extend('force', bufopts, { desc = 'Laravel: Install dump service provider' }))

            vim.keymap.set('n', '<leader>LDe', function()
                require('laravel.dump').enable()
            end, vim.tbl_extend('force', bufopts, { desc = 'Laravel: Install and enable dump capture' }))

            vim.keymap.set('n', '<leader>LDd', function()
                require('laravel.dump').disable()
            end, vim.tbl_extend('force', bufopts, { desc = 'Laravel: Disable dump capture' }))

            vim.keymap.set('n', '<leader>LDt', function()
                require('laravel.dump').toggle()
            end, vim.tbl_extend('force', bufopts, { desc = 'Laravel: Toggle dump capture' }))

            vim.keymap.set('n', '<leader>LDc', function()
                require('laravel.dump').clear()
            end, vim.tbl_extend('force', bufopts, { desc = 'Laravel: Clear dumps' }))

            -- Manual completion trigger
            vim.keymap.set('i', '<C-x><C-l>', function()
                local line = vim.fn.getline('.')
                local col = vim.fn.col('.') - 1

                local completion_source = require('laravel.completion_source')
                local context = completion_source.get_completion_context and
                    completion_source.get_completion_context(line, col)

                if context then
                    local completions = require('laravel.completions')
                    local items = completions.get_completions(context.func, context.partial)

                    if #items > 0 then
                        vim.fn.complete(col - #context.partial + 1, items)
                    else
                        vim.notify('No Laravel completions found', vim.log.levels.WARN)
                    end
                else
                    vim.notify('Not in a Laravel helper function', vim.log.levels.WARN)
                end
            end, vim.tbl_extend('force', bufopts, { desc = 'Laravel: Manual completion trigger' }))
        end,
    })

    -- Setup keymaps for Blade files
    vim.api.nvim_create_autocmd('FileType', {
        pattern = 'blade',
        callback = function()
            local bufnr = vim.api.nvim_get_current_buf()
            local bufopts = { noremap = true, silent = true, buffer = bufnr }

            -- Enhanced gd mapping for Blade files too
            vim.keymap.set('n', 'gd', function()
                -- Check if this looks like a Laravel-specific pattern first
                local navigate = require('laravel.navigate')
                if navigate.is_laravel_navigation_context() then
                    -- This is a Laravel-specific context, try Laravel navigation
                    local success = pcall(navigate.goto_laravel_string)
                    if success then
                        return -- Laravel navigation succeeded
                    end
                end

                -- Default to LSP definition for everything else
                if vim.lsp.buf.definition then
                    vim.lsp.buf.definition()
                else
                    -- Final fallback to built-in definition
                    vim.cmd('normal! gd')
                end
            end, vim.tbl_extend('force', bufopts, { desc = 'Laravel: Go to definition (Laravel strings or LSP)' }))

            vim.keymap.set('n', '<leader>Lc', function()
                require('laravel.navigate').goto_controller()
            end, vim.tbl_extend('force', bufopts, { desc = 'Laravel: Go to controller' }))

            vim.keymap.set('n', '<leader>Lv', function()
                require('laravel.navigate').goto_view()
            end, vim.tbl_extend('force', bufopts, { desc = 'Laravel: Go to view' }))

            vim.keymap.set('n', '<leader>LC', function()
                livewire.goto_livewire_component()
            end, vim.tbl_extend('force', bufopts, { desc = 'Livewire: Go to component' }))

            vim.keymap.set('n', '<leader>LV', function()
                livewire.goto_livewire_view()
            end, vim.tbl_extend('force', bufopts, { desc = 'Livewire: Go to view' }))

            vim.keymap.set('n', '<leader>LT', function()
                livewire.toggle_livewire_file()
            end, vim.tbl_extend('force', bufopts, { desc = 'Livewire: Toggle between class and view' }))
        end,
    })

    -- Setup keymaps for JavaScript/TypeScript files (for Inertia)
    vim.api.nvim_create_autocmd('FileType', {
        pattern = { 'javascript', 'typescript', 'javascriptreact', 'typescriptreact' },
        callback = function()
            local bufnr = vim.api.nvim_get_current_buf()
            local bufopts = { noremap = true, silent = true, buffer = bufnr }

            -- Enhanced gd mapping for JS/TS files in Laravel projects
            vim.keymap.set('n', 'gd', function()
                -- Check if we're in a Laravel project and this looks like a Laravel pattern
                if _G.laravel_nvim and _G.laravel_nvim.project_root then
                    local navigate = require('laravel.navigate')
                    if navigate.is_laravel_navigation_context() then
                        -- This is a Laravel-specific context, try Laravel navigation
                        local success = pcall(navigate.goto_laravel_string)
                        if success then
                            return -- Laravel navigation succeeded
                        end
                    end
                end

                -- Default to LSP definition for JS/TS
                if vim.lsp.buf.definition then
                    vim.lsp.buf.definition()
                else
                    -- Final fallback to built-in definition
                    vim.cmd('normal! gd')
                end
            end, vim.tbl_extend('force', bufopts, { desc = 'Laravel: Go to definition (Laravel strings or LSP)' }))
        end,
    })
end

-- Main setup function
function M.setup()
    setup_laravel_keymaps()
end

return M
