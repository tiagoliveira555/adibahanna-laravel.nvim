# Laravel.nvim

A comprehensive Laravel development plugin for Neovim, inspired by Laravel Idea for PhpStorm. This plugin provides intelligent navigation, autocompletion, and development tools specifically designed for Laravel projects.

## ✨ Features

### 🧭 Smart Navigation

- **Go to Definition (`gd`)**: Navigate to Laravel resources with context awareness
  - Routes: `route('dashboard')` → routes/web.php
  - Views: `view('users.index')` → resources/views/users/index.blade.php
  - Inertia: `Inertia::render('Dashboard')` → resources/js/Pages/Dashboard.tsx
  - Config: `config('app.name')` → config/app.php
  - Translations: `__('auth.failed')` → lang/en/auth.php
  - Environment variables: `env('APP_NAME')` → .env file
  - Controllers: `UserController::class` → app/Http/Controllers/UserController.php
  - Laravel globals: `auth()`, `request()`, `session()`, etc.

### 🔍 Intelligent Autocompletion

- **Route names**: Auto-complete from your route definitions
- **View names**: Complete Blade templates and Inertia components
- **Config keys**: Complete configuration keys from config files
- **Translation keys**: Complete translation keys from language files
- **Environment variables**: Complete from .env files
- **30-second caching** for optimal performance

### 📁 Automatic File Creation

- **Missing view prompt**: When navigating to non-existent views, get prompted to create them
- **Smart templates**: Detects your frontend stack (React, Vue, Svelte) and creates appropriate files
- **Directory creation**: Automatically creates necessary directory structures

### 🎯 Laravel-Specific Tools

- **Artisan integration**: Run Artisan commands with autocompletion
- **Composer integration**: Run Composer commands with interactive package management
- **Route visualization**: View and navigate your application routes
- **Migration helpers**: Navigate and manage database migrations
- **Model navigation**: Quick access to Eloquent models
- **Schema diagrams**: Visualize your database structure
- **Architecture diagrams**: See your application structure

## 📦 Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
    "adibhanna/laravel.nvim",
    dependencies = {
        "MunifTanjim/nui.nvim",
        "nvim-lua/plenary.nvim",
    },
    cmd = { "Artisan", "Composer", "Laravel*" },
    keys = {
        { "<leader>la", ":Artisan<cr>", desc = "Laravel Artisan" },
        { "<leader>lc", ":Composer<cr>", desc = "Composer" },
        { "<leader>lr", ":LaravelRoute<cr>", desc = "Laravel Routes" },
        { "<leader>lm", ":LaravelMake<cr>", desc = "Laravel Make" },
    },
    event = { "VeryLazy" },
    config = function()
        require("laravel").setup()
    end,
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
    "adibhanna/laravel.nvim",
    requires = {
        "MunifTanjim/nui.nvim",
        "nvim-lua/plenary.nvim",
    },
    config = function()
        require("laravel").setup()
    end
}
```

## ⚙️ Configuration

### Basic Setup

```lua
require("laravel").setup({
    notifications = true, -- Enable/disable Laravel.nvim notifications (default: true)
    debug = false,        -- Enable/disable debug error notifications (default: false)
    keymaps = true,       -- Enable/disable Laravel.nvim keymaps (default: true)
})
```

### Configuration Options

| Option          | Type      | Default | Description                                              |
| --------------- | --------- | ------- | -------------------------------------------------------- |
| `notifications` | `boolean` | `true`  | Enable/disable Laravel project detection notifications   |
| `debug`         | `boolean` | `false` | Enable/disable debug error notifications for completions |
| `keymaps`       | `boolean` | `true`  | Enable/disable Laravel.nvim default keymaps              |

### Examples

**Disable notifications:**

```lua
require("laravel").setup({
    notifications = false, -- No notifications when Laravel project is detected
})
```

**Enable debug mode (to see completion errors):**

```lua
require("laravel").setup({
    debug = true, -- Show completion error notifications for debugging
})
```

**Disable default keymaps (to create custom ones):**

```lua
require("laravel").setup({
    keymaps = false, -- Disable all default keymaps
})

-- Then create your own custom keymaps
vim.keymap.set('n', '<leader>a', ':Artisan<CR>')
vim.keymap.set('n', '<leader>c', ':Composer<CR>')
vim.keymap.set('n', '<leader>gc', function()
    require('laravel.navigate').goto_controller()
end)
```

### Completion Engine Integration

#### For [blink.nvim](https://github.com/saghen/blink.nvim) users:

```lua
{
    "saghen/blink.nvim",
    opts = {
        sources = {
            default = { "laravel", "lsp", "path", "snippets", "buffer" },
            providers = {
                laravel = {
                    name = "laravel",
                    module = "laravel.blink_source",
                    score_offset = 1000, -- High priority for Laravel completions
                },
            },
        },
    },
}
```

#### For [nvim-cmp](https://github.com/hrsh7th/nvim-cmp) users:

```lua
require('cmp').setup({
    sources = cmp.config.sources({
        { name = 'laravel' },
        { name = 'nvim_lsp' },
        { name = 'buffer' },
    })
})
```

## 🚀 Usage Examples

### Navigation with `gd`

#### Route Navigation

```php
// In your controller
Route::get('/dashboard', function () {
    return view('dashboard'); // Press 'gd' on 'dashboard'
});

// Press 'gd' on route name to jump to route definition
return route('dashboard'); // → routes/web.php
```

#### View Navigation

```php
// Blade templates
return view('users.index'); // → resources/views/users/index.blade.php
return view('auth.login'); // → resources/views/auth/login.blade.php

// Inertia components
return Inertia::render('Dashboard'); // → resources/js/Pages/Dashboard.tsx
return Inertia::render('users/show'); // → resources/js/Pages/users/show.tsx
```

#### Configuration Navigation

```php
// Navigate to config files
$name = config('app.name'); // → config/app.php (to 'name' key)
$driver = config('database.default'); // → config/database.php
```

#### Translation Navigation

```php
// Navigate to language files
$message = __('auth.failed'); // → lang/en/auth.php
$welcome = trans('messages.welcome'); // → lang/en/messages.php
```

#### Environment Variable Navigation

```php
// Navigate to .env file
$name = env('APP_NAME'); // → .env file (to APP_NAME line)
$debug = env('APP_DEBUG'); // → .env file (to APP_DEBUG line)
```

#### Controller Navigation

```php
// Navigate to controller classes
Route::get('/users', UserController::class); // → app/Http/Controllers/UserController.php
```

### Autocompletion Examples

#### Route Completion

```php
// Type 'route(' and get completions for:
route('dashboard')     // ← Auto-completed from routes/web.php
route('users.index')   // ← From named routes
route('api.users.show') // ← API routes included
```

#### View Completion

```php
// Type 'view(' and get completions for:
view('dashboard')        // ← From resources/views/dashboard.blade.php
view('users.index')      // ← From resources/views/users/index.blade.php
view('auth.login')       // ← Nested directories supported

// Inertia completion
Inertia::render('Dashboard')    // ← From resources/js/Pages/Dashboard.tsx
Inertia::render('users/Show')   // ← Nested components
```

#### Config Completion

```php
// Type 'config(' and get completions for:
config('app.name')           // ← From config/app.php
config('database.default')   // ← From config/database.php
config('mail.mailers.smtp')  // ← Nested keys supported
```

#### Translation Completion

```php
// Type '__(' and get completions for:
__('auth.failed')        // ← From lang/en/auth.php
__('validation.required') // ← From lang/en/validation.php
trans('messages.welcome') // ← Custom translation files
```

#### Environment Variable Completion

```php
// Type 'env(' and get completions for:
env('APP_NAME')          // ← From .env file
env('DB_CONNECTION')     // ← Database configuration
env('MAIL_MAILER')       // ← Mail configuration
```

### Composer Management Examples

#### Interactive Package Installation

```vim
:ComposerRequire
" ↓ Plugin prompts for package name
" Package name: laravel/horizon
" ↓ Plugin prompts for version (optional)
" Version constraint (optional): ^5.0
" ↓ Plugin prompts for dev dependency
" Install as dev dependency? (y/N): n
" ↓ Runs: composer require laravel/horizon:^5.0
```

#### Interactive Package Removal

```vim
:ComposerRemove
" ↓ Plugin shows fuzzy finder with installed packages
" Select package to remove:
" > laravel/horizon
"   phpunit/phpunit
"   spatie/laravel-ray
" ↓ Runs: composer remove laravel/horizon
```

#### Direct Composer Commands

```vim
:Composer install              " Install dependencies
:Composer update               " Update all packages
:Composer dump-autoload        " Regenerate autoloader
:Composer show                 " List installed packages
:Composer outdated             " Show outdated packages
:Composer validate             " Validate composer.json
```

#### Dependencies Visualization

```vim
:ComposerDependencies
" ↓ Opens buffer showing dependency tree:
" laravel/framework v10.0.0
" ├── doctrine/inflector (^2.0)
" ├── dragonmantank/cron-expression (^3.0)
" ├── egulias/email-validator (^3.0)
" └── ...
```

### File Creation Examples

When you navigate to a non-existent view, you'll be prompted to create it:

```php
// Navigate to non-existent view
return Inertia::render('onboarding/welcome');
// ↓ Plugin detects missing file and prompts:
// "Create React TypeScript view onboarding/welcome? (y/N)"
```

The plugin will:

1. **Detect your frontend stack** (React, Vue, Svelte, TypeScript)
2. **Suggest multiple options**:
   - `resources/views/onboarding/welcome.blade.php` (Blade)
   - `resources/js/Pages/onboarding/welcome.tsx` (React TypeScript)
   - `resources/js/Pages/Onboarding/Welcome.tsx` (Capitalized)
3. **Create empty files** with proper extensions
4. **Create directories** if they don't exist

## 📋 Commands

### Core Commands

| Command          | Description                     | Example                                   |
| ---------------- | ------------------------------- | ----------------------------------------- |
| `:Artisan`       | Run Laravel Artisan commands    | `:Artisan make:controller UserController` |
| `:Composer`      | Run Composer commands           | `:Composer install`                       |
| `:LaravelMake`   | Interactive make command picker | `:LaravelMake`                            |
| `:LaravelRoute`  | Show all application routes     | `:LaravelRoute`                           |
| `:LaravelStatus` | Check plugin status             | `:LaravelStatus`                          |

### Composer Commands

| Command                  | Description                    | Example                            |
| ------------------------ | ------------------------------ | ---------------------------------- |
| `:Composer [command]`    | Run any Composer command       | `:Composer update`                 |
| `:ComposerRequire [pkg]` | Interactive package require    | `:ComposerRequire laravel/horizon` |
| `:ComposerRemove [pkg]`  | Interactive package removal    | `:ComposerRemove phpunit/phpunit`  |
| `:ComposerDependencies`  | Show project dependencies tree | `:ComposerDependencies`            |

### Navigation Commands

| Command                     | Description            | Example                             |
| --------------------------- | ---------------------- | ----------------------------------- |
| `:LaravelController [name]` | Navigate to controller | `:LaravelController UserController` |
| `:LaravelModel [name]`      | Navigate to model      | `:LaravelModel User`                |
| `:LaravelView [name]`       | Navigate to view       | `:LaravelView users.index`          |

### Diagram Commands

| Command                | Description                   |
| ---------------------- | ----------------------------- |
| `:LaravelSchema`       | Show database schema diagram  |
| `:LaravelSchemaExport` | Export schema diagram to file |
| `:LaravelArchitecture` | Show application architecture |

### Cache Management

| Command                      | Description                         |
| ---------------------------- | ----------------------------------- |
| `:LaravelClearCache`         | Clear completion and composer cache |
| `:LaravelCompletions [type]` | Show completions for type           |

## ⌨️ Default Keybindings

### Global Keybindings (All PHP Files)

- `gd` - Go to definition (Laravel-aware)
- `<leader>Lc` - Go to controller
- `<leader>Lm` - Go to model
- `<leader>Lv` - Go to view
- `<leader>LR` - Show all routes
- `<leader>Lr` - Go to route file
- `<leader>La` - Run Artisan command
- `<leader>Lk` - Laravel make command
- `<leader>Ls` - Show Laravel status
- `<leader>LS` - Show schema diagram
- `<leader>LE` - Export schema diagram
- `<leader>LA` - Show architecture diagram
- `<C-x><C-l>` - Manual completion trigger (insert mode)

### Blade Templates (`*.blade.php`)

- `gd` - Go to definition (Laravel-aware)
- `<leader>Lc` - Go to controller
- `<leader>Lv` - Go to view

### Migration Files (`*/migrations/*.php`)

- `<leader>Li` - Show migration info
- `<leader>LM` - Run migration command

### Model Files (`*/Models/*.php`)

- `<leader>LR` - Show model relationships
- `<leader>LA` - Show model attributes

### JavaScript/TypeScript Files (Inertia projects)

- `gd` - Go to definition (Laravel-aware for Inertia routes)

## 🔧 Advanced Configuration

### Custom Keybindings

Laravel.nvim uses `<leader>L` (uppercase L) prefix for all keybindings to avoid conflicts with other plugins.

You can disable all default keymaps and create your own:

```lua
require("laravel").setup({
    keymaps = false, -- Disable all default keymaps
    notifications = true,
})

-- Create your own custom keymaps using available commands:
vim.keymap.set('n', '<leader>a', ':Artisan<CR>', { desc = 'Artisan' })
vim.keymap.set('n', '<leader>c', ':Composer<CR>', { desc = 'Composer' })
vim.keymap.set('n', '<leader>cr', ':ComposerRequire<CR>', { desc = 'Composer Require' })
vim.keymap.set('n', '<leader>lr', ':LaravelRoute<CR>', { desc = 'Laravel Routes' })
vim.keymap.set('n', '<leader>lc', ':LaravelController<CR>', { desc = 'Laravel Controller' })

-- Or use module functions directly:
vim.keymap.set('n', '<leader>gc', function()
    require('laravel.navigate').goto_controller()
end, { desc = 'Go to Controller' })

vim.keymap.set('n', '<leader>gm', function()
    require('laravel.navigate').goto_model()
end, { desc = 'Go to Model' })
```

**Note:** All default Laravel.nvim keybindings use `<leader>L` (uppercase) prefix to avoid conflicts with other plugins.

### Frontend Stack Detection

The plugin automatically detects your frontend stack by analyzing:

- `package.json` dependencies
- Existing files in `resources/js/Pages/`
- `tsconfig.json` for TypeScript support

Supported stacks:

- **React** (`.jsx`)
- **React TypeScript** (`.tsx`)
- **Vue** (`.vue`)
- **Svelte** (`.svelte`)

## 🎯 Laravel Functions Supported

### Route Functions

- `route('name')`
- `route('name', $parameters)`

### View Functions

- `view('name')`
- `view('name', $data)`
- `Inertia::render('component')`
- `inertia('component')`

### Configuration Functions

- `config('key')`
- `config('key', $default)`

### Translation Functions

- `__('key')`
- `trans('key')`
- `trans_choice('key', $count)`

### Environment Functions

- `env('key')`
- `env('key', $default)`

### Laravel Global Functions

- `auth()` → `config/auth.php`
- `request()` → Request documentation
- `session()` → `config/session.php`
- `cache()` → `config/cache.php`
- `storage()` → `config/filesystems.php`
- And many more Laravel helpers

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

### Development Setup

1. Clone the repository
2. Make your changes
3. Test with a Laravel project
4. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Inspired by [Laravel Idea](https://laravel-idea.com/) for PhpStorm
- Built for the Neovim community
- Thanks to all Laravel developers who make this ecosystem amazing

## 🐛 Troubleshooting

### Plugin Not Loading

- Ensure you're in a Laravel project (has `artisan` file)
- Check `:LaravelStatus` for project detection
- Verify plugin is properly installed

### Completions Not Working

- Check your completion engine integration
- Run `:LaravelClearCache` to refresh completions
- Ensure completion engine is properly configured

### Navigation Issues

- Verify file paths exist
- Check Laravel project structure
- Use `:LaravelStatus` to debug

### Performance Issues

- Completions are cached for 30 seconds
- Use `:LaravelClearCache` if needed
- Large projects may have slight delays on first load

## 📚 More Examples

### Complex Route Navigation

```php
Route::group(['prefix' => 'admin', 'middleware' => 'auth'], function () {
    Route::get('/dashboard', [AdminController::class, 'dashboard'])
         ->name('admin.dashboard'); // gd on 'admin.dashboard' works

    Route::resource('users', UserController::class);
});
```

### Nested View Navigation

```php
// Deep nesting supported
return view('admin.users.partials.form');
// → resources/views/admin/users/partials/form.blade.php

return Inertia::render('Admin/Users/Show');
// → resources/js/Pages/Admin/Users/Show.tsx
```

### Configuration with Dot Notation

```php
// All levels of nesting supported
$smtp = config('mail.mailers.smtp.host');
// → config/mail.php, navigates to nested array structure
```
