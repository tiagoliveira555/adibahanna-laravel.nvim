-- Laravel IDE Helper integration for enhanced auto-completions
-- Parses _ide_helper.php, _ide_helper_models.php, and .phpstorm.meta.php files
local M = {}

local ui = require('laravel.ui')
local sail = require('laravel.sail')

-- Cache for IDE helper completions
local cache = {
    facades = { data = {}, timestamp = 0 },
    models = { data = {}, timestamp = 0 },
    container = { data = {}, timestamp = 0 },
    fluent = { data = {}, timestamp = 0 },
}

local CACHE_TTL = 60 -- seconds (longer than regular completions since these files change less frequently)

-- Track if we've already asked about generating files this session
local _asked_about_files = false

-- Check if cache is valid
local function is_cache_valid(cache_entry)
    return (os.time() - cache_entry.timestamp) < CACHE_TTL
end

-- Get Laravel project root
local function get_project_root()
    return _G.laravel_nvim.project_root
end

-- Check if laravel-ide-helper is installed
local function is_ide_helper_installed()
    local root = get_project_root()
    if not root then return false end

    local composer_json = root .. '/composer.json'
    if vim.fn.filereadable(composer_json) == 1 then
        local content = vim.fn.readfile(composer_json)
        local json_str = table.concat(content, '\n')
        return json_str:find('"barryvdh/laravel%-ide%-helper"') ~= nil
    end
    return false
end

-- Generate IDE helper files if they don't exist
local function ensure_ide_helper_files()
    local root = get_project_root()
    if not root then return false end

    local ide_helper_file = root .. '/_ide_helper.php'
    local ide_helper_models = root .. '/_ide_helper_models.php'
    local phpstorm_meta = root .. '/.phpstorm.meta.php'

    local missing_files = {}
    if vim.fn.filereadable(ide_helper_file) == 0 then
        table.insert(missing_files, 'main helper')
    end
    if vim.fn.filereadable(ide_helper_models) == 0 then
        table.insert(missing_files, 'models')
    end
    if vim.fn.filereadable(phpstorm_meta) == 0 then
        table.insert(missing_files, 'meta')
    end

    if #missing_files > 0 then
        -- Only ask once per session to avoid annoying repeated prompts
        if _asked_about_files then
            return false
        end
        _asked_about_files = true

        local choice = vim.fn.confirm(
            'Laravel IDE Helper files missing (' .. table.concat(missing_files, ', ') ..
            '). Generate them now?\n\nThis will run:\n• php artisan ide-helper:generate\n• php artisan ide-helper:models\n• php artisan ide-helper:meta',
            '&Yes\n&No\n&Install IDE Helper first',
            1
        )

        if choice == 1 then
            -- Generate files
            local commands = {
                sail.wrap_command('php artisan ide-helper:generate'),
                sail.wrap_command('php artisan ide-helper:models --write'),
                sail.wrap_command('php artisan ide-helper:meta')
            }

            for _, cmd in ipairs(commands) do
                vim.notify('Running: ' .. cmd, vim.log.levels.INFO)
                local result = vim.fn.system('cd ' .. root .. ' && ' .. cmd)
                if vim.v.shell_error ~= 0 then
                    vim.notify('Failed to run: ' .. cmd .. '\n' .. result, vim.log.levels.ERROR)
                    return false
                end
            end

            vim.notify('IDE Helper files generated successfully!', vim.log.levels.INFO)
            _asked_about_files = false -- Reset flag since files are now generated
            return true
        elseif choice == 3 then
            vim.notify('Install laravel-ide-helper first:\ncomposer require --dev barryvdh/laravel-ide-helper',
                vim.log.levels.INFO)
            return false
        else
            return false
        end
    end

    return true
end

-- Parse facade methods from _ide_helper.php
local function parse_facade_completions()
    if is_cache_valid(cache.facades) then
        return cache.facades.data
    end

    local root = get_project_root()
    if not root then return {} end

    local ide_helper_file = root .. '/_ide_helper.php'
    if vim.fn.filereadable(ide_helper_file) == 0 then
        cache.facades.data = {}
        cache.facades.timestamp = os.time()
        return {}
    end

    local facades = {}
    local lines = vim.fn.readfile(ide_helper_file)
    local current_facade = nil

    for _, line in ipairs(lines) do
        -- Match facade class definitions: class DB extends Facade
        local facade_name = line:match('class%s+([%w_]+)%s+extends%s+.*Facade')
        if facade_name then
            current_facade = facade_name
            facades[current_facade] = {}
        end

        -- Match method signatures: @method static ReturnType methodName($param)
        if current_facade then
            local method_line = line:match('@method%s+static%s+.+%s+([%w_]+)%(')
            if method_line then
                table.insert(facades[current_facade], method_line)
            end
        end
    end

    cache.facades.data = facades
    cache.facades.timestamp = os.time()
    return facades
end

-- Parse model properties and methods from _ide_helper_models.php
local function parse_model_completions()
    if is_cache_valid(cache.models) then
        return cache.models.data
    end

    local root = get_project_root()
    if not root then return {} end

    local models_file = root .. '/_ide_helper_models.php'
    if vim.fn.filereadable(models_file) == 0 then
        cache.models.data = {}
        cache.models.timestamp = os.time()
        return {}
    end

    local models = {}
    local lines = vim.fn.readfile(models_file)
    local current_model = nil

    for _, line in ipairs(lines) do
        -- Match model class definitions
        local model_match = line:match('App\\Models\\([%w_]+)')
        if model_match then
            current_model = model_match
            models[current_model] = {
                properties = {},
                methods = {}
            }
        end

        if current_model then
            -- Match properties: @property Type $property_name
            local property = line:match('@property[%-read]*%s+[%w\\|]+%s+%$([%w_]+)')
            if property then
                table.insert(models[current_model].properties, property)
            end

            -- Match methods: @method static Builder|Model methodName()
            local method = line:match('@method%s+static%s+.+%s+([%w_]+)%(')
            if method then
                table.insert(models[current_model].methods, method)
            end
        end
    end

    cache.models.data = models
    cache.models.timestamp = os.time()
    return models
end

-- Parse container bindings from .phpstorm.meta.php
local function parse_container_completions()
    if is_cache_valid(cache.container) then
        return cache.container.data
    end

    local root = get_project_root()
    if not root then return {} end

    local meta_file = root .. '/.phpstorm.meta.php'
    if vim.fn.filereadable(meta_file) == 0 then
        cache.container.data = {}
        cache.container.timestamp = os.time()
        return {}
    end

    local bindings = {}
    local lines = vim.fn.readfile(meta_file)

    for _, line in ipairs(lines) do
        -- Match container bindings: 'service' => ServiceClass::class,
        local service, class = line:match("'([^']+)'%s*=>%s*([%w\\:]+)")
        if service and class then
            bindings[service] = class:gsub('::class', '')
        end
    end

    cache.container.data = bindings
    cache.container.timestamp = os.time()
    return bindings
end

-- Get fluent migration methods (these are typically in the main helper file)
local function parse_fluent_completions()
    if is_cache_valid(cache.fluent) then
        return cache.fluent.data
    end

    local fluent_methods = {
        -- Common fluent methods for migrations
        'after', 'autoIncrement', 'charset', 'collation', 'comment', 'default', 'first',
        'generatedAs', 'index', 'nullable', 'primary', 'storedAs', 'unique', 'unsigned',
        'useCurrent', 'useCurrentOnUpdate', 'virtualAs',
        -- Column types
        'bigIncrements', 'bigInteger', 'binary', 'boolean', 'char', 'dateTimeTz', 'date',
        'dateTime', 'decimal', 'double', 'enum', 'float', 'foreignId', 'foreignIdFor',
        'foreignUuid', 'geometryCollection', 'geometry', 'id', 'increments', 'integer',
        'ipAddress', 'json', 'jsonb', 'lineString', 'longText', 'macAddress', 'mediumIncrements',
        'mediumInteger', 'mediumText', 'morphs', 'multiLineString', 'multiPoint', 'multiPolygon',
        'nullableMorphs', 'nullableTimestamps', 'nullableUuidMorphs', 'point', 'polygon',
        'rememberToken', 'set', 'smallIncrements', 'smallInteger', 'softDeletesTz', 'softDeletes',
        'string', 'text', 'timeTz', 'time', 'timestampTz', 'timestamp', 'timestampsTz', 'timestamps',
        'tinyIncrements', 'tinyInteger', 'tinyText', 'unsignedBigInteger', 'unsignedDecimal',
        'unsignedInteger', 'unsignedMediumInteger', 'unsignedSmallInteger', 'unsignedTinyInteger',
        'uuidMorphs', 'uuid', 'year'
    }

    cache.fluent.data = fluent_methods
    cache.fluent.timestamp = os.time()
    return fluent_methods
end

-- Get facade completions for a specific facade
function M.get_facade_completions(facade_name)
    if not is_ide_helper_installed() then
        return {}
    end

    -- Try to parse completions directly, only prompt for files if really needed
    local facades = parse_facade_completions()
    return facades[facade_name] or {}
end

-- Get model completions for a specific model
function M.get_model_completions(model_name, type)
    if not is_ide_helper_installed() then
        return {}
    end

    type = type or 'properties' -- 'properties' or 'methods'
    local models = parse_model_completions()
    local model_data = models[model_name]

    if not model_data then
        return {}
    end

    return model_data[type] or {}
end

-- Get container binding completions
function M.get_container_completions()
    if not is_ide_helper_installed() then
        return {}
    end

    local bindings = parse_container_completions()
    local keys = {}

    for key, _ in pairs(bindings) do
        table.insert(keys, key)
    end

    table.sort(keys)
    return keys
end

-- Get fluent method completions (for migrations)
function M.get_fluent_completions()
    return parse_fluent_completions()
end

-- Get all available facades
function M.get_available_facades()
    if not is_ide_helper_installed() then
        return {}
    end

    local facades = parse_facade_completions()
    local facade_names = {}

    for name, _ in pairs(facades) do
        table.insert(facade_names, name)
    end

    table.sort(facade_names)
    return facade_names
end

-- Get all available models
function M.get_available_models()
    if not is_ide_helper_installed() then
        return {}
    end

    local models = parse_model_completions()
    local model_names = {}

    for name, _ in pairs(models) do
        table.insert(model_names, name)
    end

    table.sort(model_names)
    return model_names
end

-- Clear all caches
function M.clear_cache()
    for key, _ in pairs(cache) do
        cache[key] = { data = {}, timestamp = 0 }
    end
    -- Reset the "asked about files" flag
    _asked_about_files = false
end

-- Setup IDE helper integration
function M.setup()
    -- Silent setup - don't prompt for file generation during initialization
    -- Files will be checked only when IDE helper features are actually used
end

return M
