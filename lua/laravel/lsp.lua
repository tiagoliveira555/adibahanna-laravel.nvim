-- Laravel LSP configuration
local M = {}

-- LSP servers configuration for Laravel development
local servers = {
    -- PHP Language Server
    phpactor = {
        cmd = { 'phpactor', 'language-server' },
        filetypes = { 'php' },
        root_patterns = { 'composer.json', '.git', 'artisan' },
        settings = {},
    },

    -- Alternative: Intelephense (if preferred)
    intelephense = {
        cmd = { 'intelephense', '--stdio' },
        filetypes = { 'php' },
        root_patterns = { 'composer.json', '.git', 'artisan' },
        settings = {
            intelephense = {
                stubs = {
                    "bcmath", "bz2", "calendar", "Core", "curl", "date", "dba", "dom", "enchant",
                    "fileinfo", "filter", "ftp", "gd", "gettext", "hash", "iconv", "imap", "intl",
                    "json", "ldap", "libxml", "mbstring", "mcrypt", "mysql", "mysqli", "password",
                    "pcntl", "pcre", "PDO", "pdo_mysql", "Phar", "readline", "recode", "Reflection",
                    "regex", "session", "SimpleXML", "soap", "sockets", "sodium", "SPL", "sqlite3",
                    "standard", "superglobals", "sysvsem", "sysvshm", "tokenizer", "xml", "xdebug",
                    "xmlreader", "xmlwriter", "yaml", "zip", "zlib",
                    -- Laravel stubs
                    "laravel"
                },
                files = {
                    maxSize = 5000000,
                },
            },
        },
    },
}

-- Setup LSP for PHP files with Laravel enhancements
local function setup_php_lsp()
    local lspconfig_ok, lspconfig = pcall(require, 'lspconfig')
    if not lspconfig_ok then
        -- Use built-in LSP without lspconfig
        setup_builtin_lsp()
        return
    end

    -- Check which PHP LSP server is available
    local available_server = nil
    for server_name, config in pairs(servers) do
        if vim.fn.executable(config.cmd[1]) == 1 then
            available_server = server_name
            break
        end
    end

    if not available_server then
        vim.notify('No PHP LSP server found. Please install phpactor or intelephense.', vim.log.levels.WARN)
        return
    end

    local server_config = servers[available_server]

    -- Enhanced on_attach function for Laravel
    local function on_attach(client, bufnr)
        -- Enable completion triggered by <c-x><c-o>
        vim.api.nvim_buf_set_option(bufnr, 'omnifunc', 'v:lua.vim.lsp.omnifunc')

        -- Mappings
        local bufopts = { noremap = true, silent = true, buffer = bufnr }
        vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, bufopts)
        vim.keymap.set('n', 'gd', vim.lsp.buf.definition, bufopts)
        vim.keymap.set('n', 'K', vim.lsp.buf.hover, bufopts)
        vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, bufopts)
        vim.keymap.set('n', '<C-k>', vim.lsp.buf.signature_help, bufopts)
        vim.keymap.set('n', '<space>wa', vim.lsp.buf.add_workspace_folder, bufopts)
        vim.keymap.set('n', '<space>wr', vim.lsp.buf.remove_workspace_folder, bufopts)
        vim.keymap.set('n', '<space>wl', function()
            print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
        end, bufopts)
        vim.keymap.set('n', '<space>D', vim.lsp.buf.type_definition, bufopts)
        vim.keymap.set('n', '<space>rn', vim.lsp.buf.rename, bufopts)
        vim.keymap.set('n', '<space>ca', vim.lsp.buf.code_action, bufopts)
        vim.keymap.set('n', 'gr', vim.lsp.buf.references, bufopts)
        vim.keymap.set('n', '<space>f', function() vim.lsp.buf.format { async = true } end, bufopts)

        -- Laravel-specific functionality
        setup_laravel_lsp_features(client, bufnr)
    end

    -- Setup the server
    lspconfig[available_server].setup(vim.tbl_extend('force', server_config, {
        on_attach = on_attach,
        root_dir = function(fname)
            return lspconfig.util.root_pattern(unpack(server_config.root_patterns))(fname)
        end,
        capabilities = vim.lsp.protocol.make_client_capabilities(),
    }))
end

-- Setup built-in LSP without lspconfig
local function setup_builtin_lsp()
    -- Check for available PHP LSP server
    local server_cmd = nil
    local server_name = nil

    for name, config in pairs(servers) do
        if vim.fn.executable(config.cmd[1]) == 1 then
            server_cmd = config.cmd
            server_name = name
            break
        end
    end

    if not server_cmd then
        vim.notify('No PHP LSP server found. Please install phpactor or intelephense.', vim.log.levels.WARN)
        return
    end

    -- Auto-start LSP for PHP files
    vim.api.nvim_create_autocmd('FileType', {
        pattern = 'php',
        callback = function(ev)
            local root = vim.fs.root(ev.buf, { 'composer.json', '.git', 'artisan' })
            if root then
                vim.lsp.start({
                    name = server_name,
                    cmd = server_cmd,
                    root_dir = root,
                    settings = servers[server_name].settings or {},
                }, { bufnr = ev.buf })
            end
        end,
    })
end

-- Setup Laravel-specific LSP features
function setup_laravel_lsp_features(client, bufnr)
    -- Add Laravel-specific completion items
    if client.server_capabilities.completionProvider then
        -- TODO: Add Laravel-specific completions like:
        -- - Eloquent model methods
        -- - Route names
        -- - View names
        -- - Config keys
        -- - Translation keys
    end

    -- Laravel-specific hover information
    if client.server_capabilities.hoverProvider then
        -- TODO: Enhanced hover for Laravel concepts
    end

    -- Laravel-specific diagnostics
    if client.server_capabilities.diagnosticsProvider then
        -- TODO: Laravel-specific linting rules
    end
end

-- Setup Blade LSP support
local function setup_blade_lsp()
    -- For now, we'll use HTML LSP for Blade files with some customizations
    local html_lsp_available = vim.fn.executable('vscode-html-language-server') == 1

    if html_lsp_available then
        vim.api.nvim_create_autocmd('FileType', {
            pattern = 'blade',
            callback = function(ev)
                local root = vim.fs.root(ev.buf, { 'composer.json', '.git', 'artisan' })
                if root then
                    vim.lsp.start({
                        name = 'html',
                        cmd = { 'vscode-html-language-server', '--stdio' },
                        root_dir = root,
                        filetypes = { 'blade' },
                        settings = {
                            html = {
                                format = {
                                    enable = true,
                                },
                                hover = {
                                    documentation = true,
                                    references = true,
                                },
                            },
                        },
                    }, { bufnr = ev.buf })
                end
            end,
        })
    end
end

-- Setup diagnostics configuration
local function setup_diagnostics()
    vim.diagnostic.config({
        virtual_text = {
            prefix = '●',
        },
        signs = true,
        underline = true,
        update_in_insert = false,
        severity_sort = true,
    })

    -- Diagnostic signs
    local signs = { Error = " ", Warn = " ", Hint = " ", Info = " " }
    for type, icon in pairs(signs) do
        local hl = "DiagnosticSign" .. type
        vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = hl })
    end
end

-- Main setup function
function M.setup()
    setup_diagnostics()
    setup_php_lsp()
    setup_blade_lsp()

    -- Laravel-specific LSP enhancements
    vim.api.nvim_create_autocmd('LspAttach', {
        callback = function(args)
            local client = vim.lsp.get_client_by_id(args.data.client_id)
            if client and client.name:match('php') then
                -- Add Laravel-specific keymaps or functionality here
                setup_laravel_keymaps(args.buf)
            end
        end,
    })
end

-- Setup Laravel-specific keymaps
function setup_laravel_keymaps(bufnr)
    local bufopts = { noremap = true, silent = true, buffer = bufnr }

    -- Laravel-specific navigation
    vim.keymap.set('n', '<leader>lc', function()
        require('laravel.navigate').goto_controller()
    end, vim.tbl_extend('force', bufopts, { desc = 'Go to controller' }))

    vim.keymap.set('n', '<leader>lm', function()
        require('laravel.navigate').goto_model()
    end, vim.tbl_extend('force', bufopts, { desc = 'Go to model' }))

    vim.keymap.set('n', '<leader>lv', function()
        require('laravel.navigate').goto_view()
    end, vim.tbl_extend('force', bufopts, { desc = 'Go to view' }))

    vim.keymap.set('n', '<leader>lr', function()
        require('laravel.routes').show_routes()
    end, vim.tbl_extend('force', bufopts, { desc = 'Show routes' }))
end

return M
