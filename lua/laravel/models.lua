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

    local current_method = nil
    local in_method = false

    for i, line in ipairs(content) do
        -- Look for function definitions
        local method_name = line:match('function%s+(%w+)%s*%([^)]*%)')
        if method_name then
            current_method = method_name
            in_method = true
        end

        -- Look for closing brace to end method
        if in_method and line:match('^%s*}%s*$') then
            in_method = false
            current_method = nil
        end

        -- Look for relationship types in the current method
        if in_method and current_method then
            for _, rel_type in ipairs(relationship_types) do
                if line:match('%$this%->' .. rel_type) then
                    local model_class = nil

                    -- Try to extract model class from current line
                    model_class = line:match(rel_type .. '%s*%(%s*([^%s,)]+)')

                    -- If not found on current line, check next few lines
                    if not model_class then
                        for j = i + 1, math.min(i + 3, #content) do
                            local next_line = content[j]
                            model_class = next_line:match('([A-Z][%w\\]*)::[%w]+') or
                                next_line:match('[\'"]([A-Z][%w\\]*)[\'"]') or
                                next_line:match('([A-Z][%w\\]*)%.class')
                            if model_class then break end
                        end
                    end

                    if model_class then
                        model_class = model_class:gsub('[\'"]', '')
                        -- Extract just the class name if it includes namespace
                        local class_name = model_class:match('([^\\]+)$') or model_class

                        relationships[#relationships + 1] = {
                            method = current_method,
                            type = rel_type,
                            related_model = class_name,
                        }
                    end
                    break -- Found a relationship in this method, move to next line
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

    -- Debug information
    print('Debug: Found', #model_info.relationships, 'relationships in model', model_info.name)

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
                -- Add model-specific keymaps with <leader>L prefix
                vim.keymap.set('n', '<leader>LR', M.show_relationships, {
                    buffer = true,
                    desc = 'Laravel: Show model relationships'
                })

                vim.keymap.set('n', '<leader>LA', M.show_attributes, {
                    buffer = true,
                    desc = 'Laravel: Show model attributes'
                })
            end
        end,
    })
end

-- Setup function
function M.setup()
    setup_model_keymaps()
end

return M
