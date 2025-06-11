-- Laravel migrations management
local M = {}

local ui = require('laravel.ui')
local artisan = require('laravel.artisan')

-- Get Laravel project root
local function get_project_root()
    return _G.laravel_nvim.project_root
end

-- Find migration files
function M.find_migrations()
    local root = get_project_root()
    if not root then return {} end

    local migrations_path = root .. '/database/migrations'
    if vim.fn.isdirectory(migrations_path) == 0 then
        return {}
    end

    local migrations = {}
    local items = vim.fn.readdir(migrations_path)

    for _, item in ipairs(items) do
        if item:match('%.php$') then
            local full_path = migrations_path .. '/' .. item
            local timestamp = item:match('^(%d+_%d+_%d+_%d+)')
            local name = item:match('^%d+_%d+_%d+_%d+_(.+)%.php$')

            migrations[#migrations + 1] = {
                filename = item,
                name = name,
                timestamp = timestamp,
                path = full_path,
            }
        end
    end

    -- Sort by timestamp (newest first)
    table.sort(migrations, function(a, b)
        return (a.timestamp or '') > (b.timestamp or '')
    end)

    return migrations
end

-- Parse migration file content
local function parse_migration_content(file_path)
    if vim.fn.filereadable(file_path) == 0 then
        return nil
    end

    local content = vim.fn.readfile(file_path)
    local tables = {}
    local current_table = nil
    local in_up_method = false
    local in_down_method = false

    for _, line in ipairs(content) do
        -- Detect methods
        if line:match('function%s+up%s*%(') then
            in_up_method = true
            in_down_method = false
        elseif line:match('function%s+down%s*%(') then
            in_up_method = false
            in_down_method = true
        elseif line:match('function%s+') then
            in_up_method = false
            in_down_method = false
        end

        if in_up_method then
            -- Look for table operations
            local table_name = line:match('Schema::create%s*%(%s*[\'"]([^\'\"]+)[\'"]')
            if table_name then
                current_table = {
                    name = table_name,
                    action = 'create',
                    columns = {},
                }
                tables[#tables + 1] = current_table
            end

            table_name = line:match('Schema::table%s*%(%s*[\'"]([^\'\"]+)[\'"]')
            if table_name then
                current_table = {
                    name = table_name,
                    action = 'modify',
                    columns = {},
                }
                tables[#tables + 1] = current_table
            end

            -- Look for column definitions
            if current_table then
                local column_def = line:match('%$table%->([^;]+)')
                if column_def then
                    table.insert(current_table.columns, column_def)
                end
            end
        end
    end

    return {
        tables = tables,
        file_path = file_path,
    }
end

-- Show migration content
function M.show_migration_info()
    local current_file = vim.fn.expand('%:p')
    local root = get_project_root()

    if not root then
        ui.warn('Not in a Laravel project')
        return
    end

    local migrations_path = root .. '/database/migrations/'
    if not current_file:find(migrations_path, 1, true) then
        ui.warn('Not in a migration file')
        return
    end

    local migration_info = parse_migration_content(current_file)
    if not migration_info then
        ui.warn('Failed to parse migration file')
        return
    end

    local content_lines = {}
    local filename = vim.fn.fnamemodify(current_file, ':t')
    table.insert(content_lines, 'Migration: ' .. filename)
    table.insert(content_lines, string.rep('=', 50))
    table.insert(content_lines, '')

    if #migration_info.tables == 0 then
        table.insert(content_lines, 'No table operations found')
    else
        for _, table_info in ipairs(migration_info.tables) do
            table.insert(content_lines, string.format('Table: %s (%s)', table_info.name, table_info.action))
            table.insert(content_lines, string.rep('-', 30))

            if #table_info.columns > 0 then
                for _, column in ipairs(table_info.columns) do
                    table.insert(content_lines, '  ' .. column)
                end
            else
                table.insert(content_lines, '  No column definitions found')
            end
            table.insert(content_lines, '')
        end
    end

    ui.show_float(content_lines, {
        title = 'Migration Info',
        filetype = 'laravel-migration-info',
    })
end

-- Navigate to migration
function M.goto_migration()
    local migrations = M.find_migrations()
    if #migrations == 0 then
        ui.warn('No migrations found')
        return
    end

    local items = {}
    for _, migration in ipairs(migrations) do
        local display = migration.timestamp .. ' - ' .. (migration.name or migration.filename)
        items[#items + 1] = display
    end

    ui.select(items, {
        prompt = 'Select migration:',
        kind = 'laravel_migration',
    }, function(choice)
        if choice then
            local index = nil
            for i, item in ipairs(items) do
                if item == choice then
                    index = i
                    break
                end
            end

            if index and migrations[index] then
                vim.cmd('edit ' .. migrations[index].path)
            end
        end
    end)
end

-- Run migration commands
function M.migrate()
    ui.select({ 'migrate', 'migrate:rollback', 'migrate:reset', 'migrate:refresh', 'migrate:fresh' }, {
        prompt = 'Select migration command:',
        kind = 'laravel_migrate_command',
    }, function(choice)
        if choice then
            artisan.run_command(choice)
        end
    end)
end

-- Create migration snippets
local migration_snippets = {
    {
        trigger = 'column',
        body =
        '$table->${1|string,integer,bigInteger,text,boolean,json,timestamp,date,time,decimal,float,binary|}(\'${2:column_name}\')${3:->nullable()}${4:->default(${5:value})};',
    },
    {
        trigger = 'string',
        body = '$table->string(\'${1:column_name}\'${2:, ${3:255}})${4:->nullable()}${5:->default(\'${6:value}\')};',
    },
    {
        trigger = 'integer',
        body = '$table->integer(\'${1:column_name}\')${2:->nullable()}${3:->default(${4:0})};',
    },
    {
        trigger = 'bigInteger',
        body = '$table->bigInteger(\'${1:column_name}\')${2:->nullable()}${3:->default(${4:0})};',
    },
    {
        trigger = 'boolean',
        body = '$table->boolean(\'${1:column_name}\')${2:->nullable()}${3:->default(${4:false})};',
    },
    {
        trigger = 'text',
        body = '$table->text(\'${1:column_name}\')${2:->nullable()};',
    },
    {
        trigger = 'json',
        body = '$table->json(\'${1:column_name}\')${2:->nullable()};',
    },
    {
        trigger = 'timestamp',
        body = '$table->timestamp(\'${1:column_name}\')${2:->nullable()}${3:->default(DB::raw(\'CURRENT_TIMESTAMP\'))};',
    },
    {
        trigger = 'timestamps',
        body = '$table->timestamps();',
    },
    {
        trigger = 'softDeletes',
        body = '$table->softDeletes();',
    },
    {
        trigger = 'foreign',
        body =
        '$table->foreign(\'${1:column_name}\')->references(\'${2:id}\')->on(\'${3:table_name}\')${4:->onDelete(\'cascade\')};',
    },
    {
        trigger = 'index',
        body = '$table->index(\'${1:column_name}\');',
    },
    {
        trigger = 'unique',
        body = '$table->unique(\'${1:column_name}\');',
    },
    {
        trigger = 'primary',
        body = '$table->primary(\'${1:column_name}\');',
    },
    {
        trigger = 'dropColumn',
        body = '$table->dropColumn(\'${1:column_name}\');',
    },
    {
        trigger = 'renameColumn',
        body = '$table->renameColumn(\'${1:old_name}\', \'${2:new_name}\');',
    },
    {
        trigger = 'dropForeign',
        body = '$table->dropForeign([\'${1:column_name}\']);',
    },
    {
        trigger = 'dropIndex',
        body = '$table->dropIndex([\'${1:column_name}\']);',
    },
}

-- Setup migration-specific features
local function setup_migration_snippets()
    vim.api.nvim_create_autocmd('FileType', {
        pattern = 'php',
        callback = function()
            local current_file = vim.fn.expand('%:p')
            local root = get_project_root()

            if not root then return end

            -- Check if we're in a migration file
            local migrations_path = root .. '/database/migrations/'
            if current_file:find(migrations_path, 1, true) then
                -- Add migration-specific snippets using buffer-local keymaps
                for _, snippet in ipairs(migration_snippets) do
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
            end
        end,
    })
end

-- Setup migration-specific keymaps
local function setup_migration_keymaps()
    vim.api.nvim_create_autocmd('FileType', {
        pattern = 'php',
        callback = function()
            local current_file = vim.fn.expand('%:p')
            local root = get_project_root()

            if not root then return end

            -- Check if we're in a migration file
            local migrations_path = root .. '/database/migrations/'
            if current_file:find(migrations_path, 1, true) then
                -- Add migration-specific keymaps
                vim.keymap.set('n', '<leader>mi', M.show_migration_info, {
                    buffer = true,
                    desc = 'Show migration info'
                })

                vim.keymap.set('n', '<leader>mm', M.migrate, {
                    buffer = true,
                    desc = 'Run migration command'
                })
            end
        end,
    })
end

-- Setup function
function M.setup()
    setup_migration_snippets()
    setup_migration_keymaps()
end

return M
