-- Laravel Dump Viewer - Capture and display dump() and dd() calls
local M = {}

local ui = require('laravel.ui')
local job = require('laravel.utils.job')

-- State management
local dump_state = {
    enabled = false,
    window = nil,
    buffer = nil,
    dump_file = nil,
    auto_scroll = true,
    dumps = {},
    watch_job_id = nil,
    -- Search state
    search = {
        active = false,
        term = '',
    }
}

-- Configuration
local config = {
    enabled = true,
    auto_open = false, -- Changed to false - only open when explicitly requested
    auto_scroll = true,
    max_dumps = 100,
    highlight_groups = {
        timestamp = 'Comment',
        file_location = 'Directory',
        dump_content = 'Normal',
        string_value = 'String',
        number_value = 'Number',
        boolean_value = 'Boolean',
        null_value = 'Constant',
        array_key = 'Identifier',
        object_property = 'Type',
    }
}

-- Get dump file path
local function get_dump_file_path()
    if not _G.laravel_nvim or not _G.laravel_nvim.project_root then
        return nil
    end

    return _G.laravel_nvim.project_root .. '/storage/logs/nvim-dumps.log'
end

-- Format timestamp
local function format_timestamp(timestamp)
    return os.date('%H:%M:%S', timestamp)
end

-- Parse dump entry from log line
local function parse_dump_entry(line)
    -- Check if it's the new JSON format
    if line:match('^NVIM_DUMP:') then
        local json_str = line:sub(11) -- Remove "NVIM_DUMP:" prefix
        local success, data = pcall(vim.fn.json_decode, json_str)

        if success and data then
            return {
                timestamp = data.timestamp,
                file = data.file,
                line = data.line,
                content = data.content,
                type = data.type,
                formatted_time = format_timestamp(os.time()),
            }
        end
    end

    -- Fallback to old format for backwards compatibility
    local pattern = '%[([^%]]+)%] ([^:]+):(%d+) (.+)'
    local timestamp, file, line_num, content = line:match(pattern)

    if not timestamp then
        return nil
    end

    return {
        timestamp = timestamp,
        file = file,
        line = tonumber(line_num),
        content = content,
        formatted_time = format_timestamp(os.time()),
    }
end

-- Search dumps based on current search term
local function search_dumps(dumps)
    if not dump_state.search.active or dump_state.search.term == '' then
        return dumps
    end

    local filtered = {}
    local search_term = dump_state.search.term:lower()

    for _, dump in ipairs(dumps) do
        -- Search in dump content, file path, and type
        local match = (dump.content and dump.content:lower():find(search_term, 1, true)) or
            (dump.file and dump.file:lower():find(search_term, 1, true)) or
            (dump.type and dump.type:lower():find(search_term, 1, true))

        if match then
            table.insert(filtered, dump)
        end
    end

    return filtered
end

-- Format dump content with syntax highlighting
local function format_dump_content(dump_entry)
    local lines = {}

    -- Header with timestamp and location
    local header = string.format(
        '%s – %s:%d',
        dump_entry.formatted_time,
        dump_entry.file,
        dump_entry.line
    )
    table.insert(lines, header)
    table.insert(lines, '')

    -- Content - preserve multi-line formatting
    if dump_entry.content and dump_entry.content ~= '' then
        local content_lines = vim.split(dump_entry.content, '\n', { plain = true })
        for _, content_line in ipairs(content_lines) do
            -- Preserve indentation and formatting
            table.insert(lines, content_line)
        end
    else
        table.insert(lines, '(empty)')
    end

    table.insert(lines, '')
    table.insert(lines, string.rep('─', 80))
    table.insert(lines, '')

    return lines
end

-- Update dump window content
local function update_dump_window()
    if not dump_state.buffer or not vim.api.nvim_buf_is_valid(dump_state.buffer) then
        return
    end

    local lines = {}

    -- Apply search
    local filtered_dumps = search_dumps(dump_state.dumps)

    -- Add header
    table.insert(lines, '=== Laravel Dump Viewer ===')

    -- Show search status
    if dump_state.search.active and dump_state.search.term ~= '' then
        table.insert(lines, string.format('Search: "%s" | Showing: %d/%d dumps',
            dump_state.search.term, #filtered_dumps, #dump_state.dumps))
        table.insert(lines, 'Press <Esc> to clear search')
    else
        table.insert(lines, string.format('Total dumps: %d', #dump_state.dumps))
        table.insert(lines, 'Press / to search')
    end
    table.insert(lines, '')

    -- Add filtered dumps in chronological order (first dump() call appears first)
    for i = 1, #filtered_dumps do
        local dump_lines = format_dump_content(filtered_dumps[i])
        for _, line in ipairs(dump_lines) do
            table.insert(lines, line)
        end
    end

    -- Update buffer content
    vim.api.nvim_buf_set_option(dump_state.buffer, 'modifiable', true)
    vim.api.nvim_buf_set_lines(dump_state.buffer, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(dump_state.buffer, 'modifiable', false)

    -- Auto-scroll to bottom for latest dumps
    if dump_state.auto_scroll and dump_state.window and vim.api.nvim_win_is_valid(dump_state.window) and dump_state.buffer and vim.api.nvim_buf_is_valid(dump_state.buffer) then
        -- Ensure we have a valid line number (at least 1)
        local line_count = math.max(1, #lines)
        -- Additional safety check: ensure the line exists in the buffer
        local buffer_line_count = vim.api.nvim_buf_line_count(dump_state.buffer)
        if line_count <= buffer_line_count and line_count > 0 then
            -- Safely set cursor position with error handling
            local success, err = pcall(vim.api.nvim_win_set_cursor, dump_state.window, { line_count, 0 })
            if not success then
                -- If cursor setting fails, just ignore it (don't crash)
                vim.schedule(function()
                    -- Try again on next tick if needed
                    pcall(vim.api.nvim_win_set_cursor, dump_state.window, { 1, 0 })
                end)
            end
        end
    end
end

-- Apply syntax highlighting to dump buffer
local function apply_syntax_highlighting()
    if not dump_state.buffer or not vim.api.nvim_buf_is_valid(dump_state.buffer) then
        return
    end

    -- Set up syntax highlighting patterns
    vim.api.nvim_buf_call(dump_state.buffer, function()
        vim.cmd('syntax clear')

        -- Header patterns
        vim.cmd('syntax match LaravelDumpTimestamp /\\d\\+:\\d\\+:\\d\\+/')
        vim.cmd('syntax match LaravelDumpLocation /–\\s\\+[^:]*:\\d\\+/')

        -- Content patterns
        vim.cmd('syntax match LaravelDumpString /"[^"]*"/')
        vim.cmd('syntax match LaravelDumpNumber /\\<\\d\\+\\>/')
        vim.cmd('syntax match LaravelDumpBoolean /\\<\\(true\\|false\\)\\>/')
        vim.cmd('syntax match LaravelDumpNull /\\<null\\>/')
        vim.cmd('syntax match LaravelDumpSeparator /^─\\+$/')

        -- Array/Object patterns
        vim.cmd('syntax match LaravelDumpArrayKey /"[^"]*"\\s*=>/')
        vim.cmd('syntax match LaravelDumpArrayIndex /\\<\\d\\+\\s*=>/')
        vim.cmd('syntax match LaravelDumpBrackets /[\\[\\]{}]/')
        vim.cmd('syntax match LaravelDumpArrow /=>/')
        vim.cmd('syntax match LaravelDumpClass /\\<[A-Z][a-zA-Z0-9_\\\\]*\\>/')

        -- Link to color groups
        vim.cmd('highlight link LaravelDumpTimestamp ' .. config.highlight_groups.timestamp)
        vim.cmd('highlight link LaravelDumpLocation ' .. config.highlight_groups.file_location)
        vim.cmd('highlight link LaravelDumpString ' .. config.highlight_groups.string_value)
        vim.cmd('highlight link LaravelDumpNumber ' .. config.highlight_groups.number_value)
        vim.cmd('highlight link LaravelDumpBoolean ' .. config.highlight_groups.boolean_value)
        vim.cmd('highlight link LaravelDumpNull ' .. config.highlight_groups.null_value)
        vim.cmd('highlight link LaravelDumpSeparator Comment')
        vim.cmd('highlight link LaravelDumpArrayKey ' .. config.highlight_groups.array_key)
        vim.cmd('highlight link LaravelDumpArrayIndex Number')
        vim.cmd('highlight link LaravelDumpBrackets Delimiter')
        vim.cmd('highlight link LaravelDumpArrow Operator')
        vim.cmd('highlight link LaravelDumpClass ' .. config.highlight_groups.object_property)
    end)
end

-- Create dump viewer window
local function create_dump_window()
    if dump_state.window and vim.api.nvim_win_is_valid(dump_state.window) then
        -- Window already exists, just focus it
        vim.api.nvim_set_current_win(dump_state.window)
        return
    end

    -- Create floating window
    local float_opts = {
        title = '  Laravel Dumps ',
        width = math.floor(vim.o.columns * 0.9),
        height = math.floor(vim.o.lines * 0.8),
        border = 'rounded',
        filetype = 'laravel-dumps'
    }

    local float = ui.create_float(float_opts)
    dump_state.window = float.win
    dump_state.buffer = float.buf

    -- Set buffer options
    vim.api.nvim_buf_set_option(dump_state.buffer, 'buftype', 'nofile')
    vim.api.nvim_buf_set_option(dump_state.buffer, 'swapfile', false)
    vim.api.nvim_buf_set_option(dump_state.buffer, 'modifiable', false)

    -- Set up keymaps
    local function close_window()
        if dump_state.window and vim.api.nvim_win_is_valid(dump_state.window) then
            vim.api.nvim_win_close(dump_state.window, true)
            dump_state.window = nil
            dump_state.buffer = nil
        end
    end

    local function clear_dumps()
        dump_state.dumps = {}
        update_dump_window()
        ui.notify('Dumps cleared', vim.log.levels.INFO)
    end

    local function toggle_auto_scroll()
        dump_state.auto_scroll = not dump_state.auto_scroll
        local status = dump_state.auto_scroll and 'enabled' or 'disabled'
        ui.notify('Auto-scroll ' .. status, vim.log.levels.INFO)
    end

    -- Search function
    local function start_search()
        vim.ui.input({
            prompt = 'Search dumps: ',
            default = dump_state.search.term,
        }, function(input)
            if input then
                dump_state.search.term = input
                dump_state.search.active = input ~= ''
                update_dump_window()

                if input == '' then
                    ui.info('Search cleared')
                else
                    local filtered_count = #search_dumps(dump_state.dumps)
                    ui.info(string.format('Found %d matches for "%s"', filtered_count, input))
                end
            end
        end)
    end

    local function clear_search()
        if dump_state.search.active then
            dump_state.search.active = false
            dump_state.search.term = ''
            update_dump_window()
            ui.info('Search cleared')
        else
            close_window() -- If no search active, close window
        end
    end

    -- Set keymaps
    vim.keymap.set('n', 'q', close_window, { buffer = dump_state.buffer, silent = true })
    vim.keymap.set('n', '<Esc>', clear_search,
        { buffer = dump_state.buffer, silent = true, desc = 'Clear search or close' })
    vim.keymap.set('n', 'c', clear_dumps, { buffer = dump_state.buffer, silent = true, desc = 'Clear dumps' })
    vim.keymap.set('n', 's', toggle_auto_scroll,
        { buffer = dump_state.buffer, silent = true, desc = 'Toggle auto-scroll' })
    vim.keymap.set('n', 'r', update_dump_window, { buffer = dump_state.buffer, silent = true, desc = 'Refresh' })

    -- Search keymap
    vim.keymap.set('n', '/', start_search,
        { buffer = dump_state.buffer, silent = true, desc = 'Search dumps' })

    -- Apply syntax highlighting
    apply_syntax_highlighting()

    -- Update content
    update_dump_window()

    return float
end

-- Add new dump entry
local function add_dump(dump_entry)
    -- Add to the end for chronological order (first dump() call appears first)
    table.insert(dump_state.dumps, dump_entry)

    -- Limit number of stored dumps (remove from the beginning)
    if #dump_state.dumps > config.max_dumps then
        table.remove(dump_state.dumps, 1)
    end

    -- Update window if open
    if dump_state.window and vim.api.nvim_win_is_valid(dump_state.window) then
        update_dump_window()
    elseif config.auto_open then
        create_dump_window()
    else
        -- Show a subtle notification that new dumps are available
        if #dump_state.dumps == 1 then -- Only notify for the first dump
            ui.info('New Laravel dump captured. Open with :LaravelDumps or <leader>Ld')
        end
    end
end

-- Load existing dumps from file
local function load_existing_dumps()
    local dump_file = get_dump_file_path()
    if not dump_file or vim.fn.filereadable(dump_file) == 0 then
        return
    end

    local file = io.open(dump_file, 'r')
    if not file then
        return
    end

    local lines = {}
    for line in file:lines() do
        table.insert(lines, line)
    end
    file:close()

    -- Process only the last 20 dumps to avoid overwhelming the UI
    local start_index = math.max(1, #lines - 19)
    for i = start_index, #lines do
        local line = lines[i]
        if line and line ~= '' then
            local dump_entry = parse_dump_entry(line)
            if dump_entry then
                -- Add to end, then we'll reverse later
                table.insert(dump_state.dumps, dump_entry)
            end
        end
    end

    -- Reverse to show newest first
    local reversed = {}
    for i = #dump_state.dumps, 1, -1 do
        table.insert(reversed, dump_state.dumps[i])
    end
    dump_state.dumps = reversed
end

-- Watch dump file for changes using timer-based approach
local function start_file_watcher()
    local dump_file = get_dump_file_path()
    if not dump_file then
        return
    end

    dump_state.dump_file = dump_file

    -- Create directory if it doesn't exist
    local log_dir = vim.fn.fnamemodify(dump_file, ':h')
    vim.fn.mkdir(log_dir, 'p')

    -- Create the file if it doesn't exist
    if vim.fn.filereadable(dump_file) == 0 then
        local file = io.open(dump_file, 'w')
        if file then
            file:close()
        end
    end

    -- Track last file size to detect new content
    local last_size = vim.fn.getfsize(dump_file)
    if last_size < 0 then
        last_size = 0
    end

    -- Timer-based file watching
    local function check_file_changes()
        local current_size = vim.fn.getfsize(dump_file)
        if current_size < 0 then
            return -- File doesn't exist or error
        end

        if current_size < last_size then
            -- File was truncated/cleared, clear our dumps too
            dump_state.dumps = {}
            if dump_state.window and vim.api.nvim_win_is_valid(dump_state.window) then
                update_dump_window()
            end
            last_size = current_size
            ui.info('Log file cleared, dumps cleared from viewer')
        elseif current_size > last_size then
            -- File has grown, read new content
            local file = io.open(dump_file, 'r')
            if file then
                file:seek('set', last_size) -- Start from where we left off

                local lines_processed = 0
                for line in file:lines() do
                    if line and line ~= '' then
                        lines_processed = lines_processed + 1
                        local dump_entry = parse_dump_entry(line)
                        if dump_entry then
                            add_dump(dump_entry)
                        end
                    end
                end

                file:close()
                last_size = current_size
            end
        end
    end

    -- Start timer that checks every 500ms
    local timer = vim.loop.new_timer()
    timer:start(500, 500, vim.schedule_wrap(check_file_changes))

    dump_state.watch_job_id = timer -- Store timer instead of job_id
end

-- Stop file watcher
local function stop_file_watcher()
    if dump_state.watch_job_id then
        if type(dump_state.watch_job_id) == 'userdata' then
            -- It's a timer
            dump_state.watch_job_id:stop()
            dump_state.watch_job_id:close()
        else
            -- It's a job (legacy)
            vim.fn.jobstop(dump_state.watch_job_id)
        end
        dump_state.watch_job_id = nil
    end
end

-- Register in Laravel 11+ bootstrap/app.php
local function register_in_bootstrap_app(bootstrap_path)
    local file = io.open(bootstrap_path, 'r')
    if not file then
        return false
    end

    local content = file:read('*all')
    file:close()

    -- Check if provider is already registered
    if content:find('NvimDumpServiceProvider') then
        return true
    end

    -- Look for withProviders pattern
    local pattern = "(->withProviders%s*%(%s*%[)([^%]]*)(]%s*%)"
    local start_match, end_match, before_providers, providers, after_providers = content:find(pattern)

    if start_match then
        -- Add our provider to the existing withProviders array
        local new_providers = providers
        if providers:match('%S') then -- If there are existing providers
            new_providers = providers .. ",\n        App\\Providers\\NvimDumpServiceProvider::class"
        else
            new_providers = "\n        App\\Providers\\NvimDumpServiceProvider::class,\n    "
        end

        local new_content = content:sub(1, start_match - 1) ..
            before_providers .. new_providers .. after_providers ..
            content:sub(end_match + 1)

        -- Write the updated file
        file = io.open(bootstrap_path, 'w')
        if not file then
            return false
        end
        file:write(new_content)
        file:close()
        return true
    else
        -- No withProviders found, try to add it
        -- Look for a spot to add withProviders
        pattern = "(Application::configure%(.-%))(.-)(->create%(%)"
        local new_content, count = content:gsub(pattern, function(configure, middle, create)
            return configure .. middle ..
                "    ->withProviders([\n        App\\Providers\\NvimDumpServiceProvider::class,\n    ])\n    " ..
                create
        end)

        if count > 0 then
            file = io.open(bootstrap_path, 'w')
            if not file then
                return false
            end
            file:write(new_content)
            file:close()
            return true
        end
    end

    return false
end

-- Register in Laravel 10 config/app.php
local function register_in_config_app(config_path)
    local file = io.open(config_path, 'r')
    if not file then
        return false
    end

    local content = file:read('*all')
    file:close()

    -- Check if provider is already registered
    if content:find('NvimDumpServiceProvider') then
        return true
    end

    -- Find the providers array and add our provider
    local pattern = "('providers'%s*=>%s*%[.-)(App\\Providers\\RouteServiceProvider::class,)"
    local replacement = "%1%2\n        App\\Providers\\NvimDumpServiceProvider::class,"

    local new_content, count = content:gsub(pattern, replacement)

    if count == 0 then
        -- Try alternative pattern for different Laravel versions
        pattern = "('providers'%s*=>%s*%[.-)(App\\\\Providers\\\\RouteServiceProvider::class,)"
        replacement = "%1%2\n        App\\\\Providers\\\\NvimDumpServiceProvider::class,"
        new_content, count = content:gsub(pattern, replacement)
    end

    if count == 0 then
        return false
    end

    -- Write the updated config
    file = io.open(config_path, 'w')
    if not file then
        return false
    end

    file:write(new_content)
    file:close()

    return true
end

-- Register the service provider in Laravel's config
local function register_service_provider()
    if not _G.laravel_nvim or not _G.laravel_nvim.project_root then
        return false
    end

    local project_root = _G.laravel_nvim.project_root

    -- Try Laravel 11+ first (bootstrap/app.php)
    local bootstrap_path = project_root .. '/bootstrap/app.php'
    if vim.fn.filereadable(bootstrap_path) == 1 then
        local success = register_in_bootstrap_app(bootstrap_path)
        if success then
            return true
        end
    end

    -- Fallback to Laravel 10 (config/app.php)
    local config_path = project_root .. '/config/app.php'
    if vim.fn.filereadable(config_path) == 1 then
        return register_in_config_app(config_path)
    end

    ui.warn('Could not find bootstrap/app.php or config/app.php. Please register NvimDumpServiceProvider manually.')
    return true -- Still return true as the provider file was created
end

-- Install PHP dump handler
local function install_php_handler()
    if not _G.laravel_nvim or not _G.laravel_nvim.project_root then
        ui.error('Not in a Laravel project')
        return false
    end

    local project_root = _G.laravel_nvim.project_root

    -- Create the service provider
    local provider_dir = project_root .. '/app/Providers'
    local provider_path = provider_dir .. '/NvimDumpServiceProvider.php'

    -- Check if provider already exists
    if vim.fn.filereadable(provider_path) == 1 then
        return true
    end

    -- Ensure the Providers directory exists
    vim.fn.mkdir(provider_dir, 'p')

    -- Create the service provider with improved caller detection
    local provider_content = [[<?php

namespace App\Providers;

use Illuminate\Support\ServiceProvider;
use Symfony\Component\VarDumper\VarDumper;
use Symfony\Component\VarDumper\Cloner\VarCloner;
use Symfony\Component\VarDumper\Dumper\CliDumper;

class NvimDumpServiceProvider extends ServiceProvider
{
    /**
     * Register services.
     */
    public function register(): void
    {
        //
    }

    /**
     * Bootstrap services.
     */
    public function boot(): void
    {
        if (!app()->environment('local')) {
            return;
        }

        // Set up custom dump handler for Neovim
        VarDumper::setHandler(function ($var) {
            $cloner = new VarCloner();
            $dumper = new NvimCliDumper();

            // Get caller information - we need to look deeper in the stack
            $trace = debug_backtrace(DEBUG_BACKTRACE_IGNORE_ARGS, 20);
            $caller = null;

            // Multi-pass approach: prioritize route files, then controllers, then any user code
            $routeCaller = null;
            $controllerCaller = null;
            $userCodeCaller = null;
            $fallbackCaller = null;

            foreach ($trace as $frame) {
                $file = $frame['file'] ?? '';
                $function = $frame['function'] ?? '';
                $class = $frame['class'] ?? '';

                // Skip internal frames we don't want to show
                $skipConditions = [
                    // Skip framework internals
                    strpos($file, 'laravel/framework') !== false,
                    strpos($file, 'symfony/var-dumper') !== false,

                    // Skip this service provider
                    strpos($file, 'NvimDumpServiceProvider.php') !== false,

                    // Skip VarDumper internal functions
                    strpos($class, 'Symfony\\Component\\VarDumper') !== false,

                    // Skip closure/anonymous functions (our handler)
                    $function === '{closure}',

                    // Skip call_user_func type calls
                    in_array($function, ['call_user_func', 'call_user_func_array']),
                ];

                // Special case: Don't skip dump functions if they're in user code
                // (This is where the actual dump() call happened)
                $isDumpFunction = in_array($function, ['dump', 'dd', 'ddd', 'ray']);
                $isUserCodeFile = (
                    strpos($file, 'routes/') !== false ||
                    strpos($file, 'app/Http/Controllers/') !== false ||
                    strpos($file, 'app/Models/') !== false ||
                    strpos($file, 'app/Services/') !== false ||
                    (strpos($file, 'app/') !== false &&
                     strpos($file, 'vendor/') === false &&
                     strpos($file, 'app/Http/Middleware/') === false)
                );

                // If it's a dump function in user code, don't skip it
                if ($isDumpFunction && $isUserCodeFile) {
                    // This is exactly what we want - the user's dump() call
                } else if ($isDumpFunction) {
                    // Skip dump functions in framework/vendor code
                    $skipConditions[] = true;
                }

                $shouldSkip = false;
                foreach ($skipConditions as $condition) {
                    if ($condition) {
                        $shouldSkip = true;
                        break;
                    }
                }

                if (!$shouldSkip && !empty($file)) {
                    // Always store as fallback
                    if (!$fallbackCaller) {
                        $fallbackCaller = $frame;
                    }

                    // Check for route files (highest priority)
                    if (strpos($file, 'routes/') !== false) {
                        $routeCaller = $frame;
                        break; // Routes have highest priority
                    }

                    // Check for controllers (second priority)
                    if (strpos($file, 'app/Http/Controllers/') !== false) {
                        if (!$controllerCaller) {
                            $controllerCaller = $frame;
                        }
                    }

                    // Check for other user code (third priority)
                    if ($isUserCodeFile && !$userCodeCaller) {
                        $userCodeCaller = $frame;
                    }
                }
            }

            // Priority order: routes > controllers > user code > fallback
            $caller = $routeCaller ?: $controllerCaller ?: $userCodeCaller ?: $fallbackCaller;

            $dumper->setCallerInfo($caller);
            $dumper->dump($cloner->cloneVar($var));
        });
    }
}

class NvimCliDumper extends CliDumper
{
    private static $logFile;
    private $callerInfo;

    public function __construct()
    {
        parent::__construct();

        if (!self::$logFile) {
            self::$logFile = storage_path('logs/nvim-dumps.log');

            // Ensure log directory exists
            $logDir = dirname(self::$logFile);
            if (!is_dir($logDir)) {
                mkdir($logDir, 0755, true);
            }
        }
    }

    public function setCallerInfo($callerInfo)
    {
        $this->callerInfo = $callerInfo;
    }

    public function dump($data, $output = null, array $extraDisplayOptions = []): string
    {
        // Create a string output stream to capture dump content
        $outputStream = fopen('php://memory', 'r+');

        // Dump to the stream to capture content
        $originalOutput = parent::dump($data, $outputStream, $extraDisplayOptions);

        // Get the captured content
        rewind($outputStream);
        $capturedOutput = stream_get_contents($outputStream);
        fclose($outputStream);

        // Use the caller info if available, otherwise fallback to debug_backtrace
        $caller = $this->callerInfo ?? $this->findRelevantCaller(debug_backtrace(DEBUG_BACKTRACE_IGNORE_ARGS, 10));

        $timestamp = date('Y-m-d H:i:s');
        $file = $caller['file'] ?? 'unknown';
        $line = $caller['line'] ?? 0;

        // Make file path relative to project root
        $projectRoot = base_path();
        if (strpos($file, $projectRoot) === 0) {
            $file = substr($file, strlen($projectRoot) + 1);
        }

        // Use captured output or fallback to a string representation
        $dumpContent = $capturedOutput ?: var_export($data, true);

        // Clean and format the dump output
        $cleanOutput = $this->cleanDumpOutput($dumpContent);

        // Create a structured log entry that can be easily parsed
        $logEntry = json_encode([
            'timestamp' => $timestamp,
            'file' => $file,
            'line' => $line,
            'content' => $cleanOutput,
            'type' => gettype($data)
        ], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);

        // Write to Neovim log file with a special delimiter
        $logLine = "NVIM_DUMP:" . $logEntry . "\n";
        file_put_contents(self::$logFile, $logLine, FILE_APPEND | LOCK_EX);

        // Also output to console like normal dump()
        echo $capturedOutput;

        return $originalOutput ?? '';
    }

    private function findRelevantCaller(array $trace): array
    {
        foreach ($trace as $frame) {
            $file = $frame['file'] ?? '';
            $function = $frame['function'] ?? '';

            // Skip internal Laravel/Symfony dump functions and this service provider
            if (
                strpos($file, 'laravel/framework') === false &&
                strpos($file, 'symfony/var-dumper') === false &&
                strpos($file, 'NvimDumpServiceProvider.php') === false &&
                !in_array($function, ['dump', 'dd', 'ddd', 'ray'])
            ) {
                return $frame;
            }
        }

        return $trace[0] ?? [];
    }

    private function cleanDumpOutput($output): string
    {
        // Convert to string if needed
        $output = (string) $output;

        // Remove ANSI color codes and control characters
        $output = preg_replace('/\x1b\[[0-9;]*m/', '', $output);

        // Remove excessive whitespace
        $output = preg_replace('/\n\s*\n/', "\n", $output);
        $output = trim($output);

        return $output;
    }
}
]]

    -- Write the service provider
    local file = io.open(provider_path, 'w')
    if not file then
        ui.error('Failed to create service provider')
        return false
    end

    file:write(provider_content)
    file:close()

    -- Register the service provider
    local registration_success = register_service_provider()
    if registration_success then
        ui.info('✅ Laravel dump handler service provider installed successfully!')
        ui.info('📝 Created: app/Providers/NvimDumpServiceProvider.php')
        ui.info('🔧 Registered in Laravel application')
        ui.info('🚀 Ready to capture dump() calls in Neovim!')
        return true
    else
        ui.warn('⚠️  Service provider created but automatic registration failed')
        ui.info('📝 Created: app/Providers/NvimDumpServiceProvider.php')
        ui.warn('⚙️  Manual setup required:')

        -- Check Laravel version and provide specific instructions
        local project_root = _G.laravel_nvim.project_root
        local bootstrap_path = project_root .. '/bootstrap/app.php'

        if vim.fn.filereadable(bootstrap_path) == 1 then
            ui.warn('   Add to bootstrap/app.php (Laravel 11+):')
            ui.warn('   ->withProviders([')
            ui.warn('       App\\Providers\\NvimDumpServiceProvider::class,')
            ui.warn('   ])')
        else
            ui.warn('   Add to config/app.php providers array (Laravel 10):')
            ui.warn('   App\\Providers\\NvimDumpServiceProvider::class,')
        end

        return true -- Provider was created successfully
    end
end

-- Public API
function M.setup(opts)
    config = vim.tbl_deep_extend('force', config, opts or {})
    -- Note: We don't automatically install the PHP handler or enable dump capture
    -- Users must explicitly run :LaravelDumpsEnable to set it up
end

function M.toggle()
    if dump_state.enabled then
        M.disable()
    else
        M.enable()
    end
end

function M.install()
    -- Just install the service provider without enabling
    return install_php_handler()
end

function M.enable()
    if not dump_state.enabled then
        if install_php_handler() then
            start_file_watcher()
            dump_state.enabled = true
            ui.info('Laravel dump viewer enabled')
        end
    else
        ui.info('Laravel dump viewer already enabled')
    end
end

function M.disable()
    if dump_state.enabled then
        stop_file_watcher()
        if dump_state.window and vim.api.nvim_win_is_valid(dump_state.window) then
            vim.api.nvim_win_close(dump_state.window, true)
        end
        dump_state.enabled = false
        ui.info('Laravel dump viewer disabled')
    end
end

function M.open()
    if not dump_state.enabled then
        ui.error('Dump viewer not enabled. Run :LaravelDumpsEnable first')
        return
    end

    create_dump_window()
end

function M.close()
    if dump_state.window and vim.api.nvim_win_is_valid(dump_state.window) then
        vim.api.nvim_win_close(dump_state.window, true)
        dump_state.window = nil
        dump_state.buffer = nil
    end
end

function M.clear()
    dump_state.dumps = {}
    if dump_state.window and vim.api.nvim_win_is_valid(dump_state.window) then
        update_dump_window()
    end
    ui.info('Dumps cleared')
end

function M.is_enabled()
    return dump_state.enabled
end

function M.get_dumps()
    return dump_state.dumps
end

-- Search functions
function M.search(term)
    dump_state.search.term = term or ''
    dump_state.search.active = term and term ~= ''

    if dump_state.window and vim.api.nvim_win_is_valid(dump_state.window) then
        update_dump_window()
    end

    if term and term ~= '' then
        local filtered_count = #search_dumps(dump_state.dumps)
        ui.info(string.format('Found %d matches for "%s"', filtered_count, term))
    else
        ui.info('Search cleared')
    end
end

function M.clear_search()
    dump_state.search.active = false
    dump_state.search.term = ''

    if dump_state.window and vim.api.nvim_win_is_valid(dump_state.window) then
        update_dump_window()
    end

    ui.info('Search cleared')
end

-- Utility functions
function M.get_log_file_path()
    return get_dump_file_path()
end

function M.get_status()
    return {
        enabled = dump_state.enabled,
        project_root = _G.laravel_nvim and _G.laravel_nvim.project_root or 'not set',
        log_file_path = get_dump_file_path(),
        watch_job_id = dump_state.watch_job_id,
        dump_count = #dump_state.dumps,
        window_open = dump_state.window and vim.api.nvim_win_is_valid(dump_state.window) or false
    }
end

function M.restart_watcher()
    ui.info('Restarting file watcher...')
    stop_file_watcher()
    start_file_watcher()
    ui.info('File watcher restarted')
end

return M
