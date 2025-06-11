-- Laravel models management
local M = {}

local ui = require('laravel.ui')

-- Get Laravel project root
local function get_project_root()
    return _G.laravel_nvim.project_root
end

-- Extract model relationships from file content
local function extract_relationships(content)
    local relationships = {}
    local relationship_types = {
        'hasOne', 'hasMany', 'belongsTo', 'belongsToMany',
        'morphOne', 'morphMany', 'morphTo', 'morphToMany',
        'morphedByMany'
    }

    for _, line in ipairs(content) do
        for _, rel_type in ipairs(relationship_types) do
            local pattern = 'function%s+(%w+)%s*%([^)]*%)%s*{?%s*return%s*%$this%->' .. rel_type
            local method_name = line:match(pattern)
            if method_name then
                local model_class = line:match(rel_type .. '%s*%(%s*([^%s,)]+)')
                if model_class then
                    model_class = model_class:gsub('[\'"]', '')
                    relationships[#relationships + 1] = {
                        method = method_name,
                        type = rel_type,
                        related_model = model_class,
                    }
                end
            end
        end
    end

    return relationships
end

-- Extract model attributes from file content
local function extract_attributes(content)
    local attributes = {}
    local in_fillable = false
    local in_hidden = false
    local in_casts = false

    for _, line in ipairs(content) do
        -- Check for fillable array
        if line:match('protected%s+%$fillable%s*=') then
            in_fillable = true
        elseif line:match('protected%s+%$hidden%s*=') then
            in_hidden = true
        elseif line:match('protected%s+%$casts%s*=') then
            in_casts = true
        elseif in_fillable or in_hidden or in_casts then
            -- Extract attributes from arrays
            local attr = line:match('[\'"]([%w_]+)[\'"]')
            if attr then
                local attr_type = 'fillable'
                if in_hidden then
                    attr_type = 'hidden'
                elseif in_casts then
                    attr_type = 'casts'
                end

                attributes[#attributes + 1] = {
                    name = attr,
                    type = attr_type,
                }
            end

            -- End of array
            if line:match('];') then
                in_fillable = false
                in_hidden = false
                in_casts = false
            end
        end
    end

    return attributes
end

-- Analyze model file
function M.analyze_model(file_path)
    if vim.fn.filereadable(file_path) == 0 then
        return nil
    end

    local content = vim.fn.readfile(file_path)
    local model_name = vim.fn.fnamemodify(file_path, ':t:r')

    -- Extract class information
    local namespace = nil
    local extends = nil
    local implements = {}
    local traits = {}

    for _, line in ipairs(content) do
        if line:match('^namespace%s+') then
            namespace = line:match('namespace%s+([^;]+)')
        elseif line:match('class%s+' .. model_name) then
            extends = line:match('extends%s+([%w\\]+)')
            local implements_str = line:match('implements%s+([^{]+)')
            if implements_str then
                for impl in implements_str:gmatch('([%w\\]+)') do
                    implements[#implements + 1] = impl
                end
            end
        elseif line:match('use%s+[%w\\]+;') and not line:match('^use%s+') then
            local trait = line:match('use%s+([%w\\]+);')
            if trait then
                traits[#traits + 1] = trait
            end
        end
    end

    return {
        name = model_name,
        namespace = namespace,
        extends = extends,
        implements = implements,
        traits = traits,
        relationships = extract_relationships(content),
        attributes = extract_attributes(content),
        file_path = file_path,
    }
end

-- Get model info for current buffer
function M.get_current_model_info()
    local current_file = vim.fn.expand('%:p')
    local root = get_project_root()

    if not root then return nil end

    -- Check if current file is a model
    local models_path = root .. '/app/Models/'
    local app_path = root .. '/app/'

    if current_file:find(models_path, 1, true) or
        (current_file:find(app_path, 1, true) and current_file:match('%.php$')) then
        return M.analyze_model(current_file)
    end

    return nil
end

-- Show model relationships
function M.show_relationships()
    local model_info = M.get_current_model_info()
    if not model_info then
        ui.warn('Not in a model file')
        return
    end

    if #model_info.relationships == 0 then
        ui.info('No relationships found in this model')
        return
    end

    local content_lines = {}
    table.insert(content_lines, 'Model: ' .. model_info.name)
    table.insert(content_lines, string.rep('=', 50))
    table.insert(content_lines, '')
    table.insert(content_lines, 'Relationships:')
    table.insert(content_lines, string.rep('-', 20))

    for _, rel in ipairs(model_info.relationships) do
        table.insert(content_lines, string.format('  %s() -> %s (%s)',
            rel.method, rel.related_model, rel.type))
    end

    ui.show_float(content_lines, {
        title = 'Model Relationships',
        filetype = 'laravel-model-info',
    })
end

-- Show model attributes
function M.show_attributes()
    local model_info = M.get_current_model_info()
    if not model_info then
        ui.warn('Not in a model file')
        return
    end

    if #model_info.attributes == 0 then
        ui.info('No attributes found in this model')
        return
    end

    local content_lines = {}
    table.insert(content_lines, 'Model: ' .. model_info.name)
    table.insert(content_lines, string.rep('=', 50))
    table.insert(content_lines, '')

    -- Group attributes by type
    local grouped = {}
    for _, attr in ipairs(model_info.attributes) do
        if not grouped[attr.type] then
            grouped[attr.type] = {}
        end
        table.insert(grouped[attr.type], attr.name)
    end

    for type_name, attrs in pairs(grouped) do
        table.insert(content_lines, string.upper(type_name) .. ':')
        table.insert(content_lines, string.rep('-', #type_name + 1))
        for _, attr_name in ipairs(attrs) do
            table.insert(content_lines, '  ' .. attr_name)
        end
        table.insert(content_lines, '')
    end

    ui.show_float(content_lines, {
        title = 'Model Attributes',
        filetype = 'laravel-model-info',
    })
end

-- Navigate to related model
function M.goto_related_model()
    local model_info = M.get_current_model_info()
    if not model_info then
        ui.warn('Not in a model file')
        return
    end

    if #model_info.relationships == 0 then
        ui.info('No relationships found in this model')
        return
    end

    local items = {}
    for _, rel in ipairs(model_info.relationships) do
        items[#items + 1] = string.format('%s (%s)', rel.related_model, rel.type)
    end

    ui.select(items, {
        prompt = 'Select related model:',
        kind = 'laravel_related_model',
    }, function(choice)
        if choice then
            local model_name = choice:match('([^%s%(]+)')
            require('laravel.navigate').goto_model(model_name)
        end
    end)
end

-- Create model snippets
local model_snippets = {
    {
        trigger = 'relationship',
        body = [[
public function ${1:relationName}()
{
    return $this->${2|hasOne,hasMany,belongsTo,belongsToMany|}(${3:RelatedModel}::class);
}]],
    },
    {
        trigger = 'hasOne',
        body = [[
public function ${1:relationName}()
{
    return $this->hasOne(${2:RelatedModel}::class);
}]],
    },
    {
        trigger = 'hasMany',
        body = [[
public function ${1:relationName}()
{
    return $this->hasMany(${2:RelatedModel}::class);
}]],
    },
    {
        trigger = 'belongsTo',
        body = [[
public function ${1:relationName}()
{
    return $this->belongsTo(${2:RelatedModel}::class);
}]],
    },
    {
        trigger = 'belongsToMany',
        body = [[
public function ${1:relationName}()
{
    return $this->belongsToMany(${2:RelatedModel}::class);
}]],
    },
    {
        trigger = 'scope',
        body = [[
public function scope${1:ScopeName}($query${2:, $param})
{
    return $query${3:->where('column', $param)};
}]],
    },
    {
        trigger = 'mutator',
        body = [[
public function set${1:AttributeName}Attribute($value)
{
    return $this->attributes['${2:attribute_name}'] = ${3:$value};
}]],
    },
    {
        trigger = 'accessor',
        body = [[
public function get${1:AttributeName}Attribute()
{
    return ${2:$this->attributes['${3:attribute_name}']};
}]],
    },
}

-- Setup model-specific features
local function setup_model_snippets()
    vim.api.nvim_create_autocmd('FileType', {
        pattern = 'php',
        callback = function()
            local current_file = vim.fn.expand('%:p')
            local root = get_project_root()

            if not root then return end

            -- Check if we're in a model file
            local models_path = root .. '/app/Models/'
            local app_path = root .. '/app/'

            if current_file:find(models_path, 1, true) or
                (current_file:find(app_path, 1, true) and current_file:match('%.php$')) then
                -- Add model-specific snippets using buffer-local abbreviations
                for _, snippet in ipairs(model_snippets) do
                    local trigger = snippet.trigger
                    local body = snippet.body

                    -- Create buffer-local abbreviation that expands to snippet
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

-- Setup model-specific keymaps
local function setup_model_keymaps()
    vim.api.nvim_create_autocmd('FileType', {
        pattern = 'php',
        callback = function()
            local current_file = vim.fn.expand('%:p')
            local root = get_project_root()

            if not root then return end

            -- Check if we're in a model file
            local models_path = root .. '/app/Models/'
            local app_path = root .. '/app/'

            if current_file:find(models_path, 1, true) or
                (current_file:find(app_path, 1, true) and current_file:match('%.php$')) then
                -- Add model-specific keymaps
                vim.keymap.set('n', '<leader>mr', M.show_relationships, {
                    buffer = true,
                    desc = 'Show model relationships'
                })

                vim.keymap.set('n', '<leader>ma', M.show_attributes, {
                    buffer = true,
                    desc = 'Show model attributes'
                })

                vim.keymap.set('n', '<leader>mg', M.goto_related_model, {
                    buffer = true,
                    desc = 'Go to related model'
                })
            end
        end,
    })
end

-- Setup function
function M.setup()
    setup_model_snippets()
    setup_model_keymaps()
end

return M
