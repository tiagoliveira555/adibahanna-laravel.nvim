# Laravel.nvim

A comprehensive Laravel plugin for Neovim that brings Laravel Idea-like functionality to your favorite editor. Navigate your Laravel projects with ease using intelligent go-to-definition and smart autocompletion.

## ✨ Features

### 🧭 **Smart Navigation (`gd`)**
Press `gd` on any Laravel string reference to instantly jump to the corresponding file:

- **Routes**: `route('dashboard')` → jumps to route definition in `routes/*.php`
- **Views**: `view('users.index')` → opens `resources/views/users/index.blade.php`
- **Inertia**: `Inertia::render('dashboard')` → opens `resources/js/Pages/dashboard.tsx`
- **Config**: `config('app.name')` → opens `config/app.php` and finds the key
- **Translations**: `__('auth.failed')` → opens `lang/en/auth.php` and finds the key

### 🚀 **Intelligent Autocompletion**
Get context-aware completions for Laravel helpers with **highest priority** in your completion list:

- **Route names**: Auto-complete from your route definitions
- **View names**: Complete Blade templates and Inertia components  
- **Config keys**: Complete from your `config/*.php` files
- **Translation keys**: Complete from your `lang/*.php` files

### 🎯 **Supported Patterns**
The plugin intelligently detects these Laravel patterns:

```php
// Route navigation
route('dashboard')
route('profile.edit')

// View navigation  
view('users.index')
view('auth.login')
Inertia::render('dashboard')
inertia('settings/profile')

// Config navigation
config('app.name')
config('database.default')

// Translation navigation
__('auth.failed')
trans('validation.required')
```

### 📁 **File Support**
- **PHP files**: Full Laravel navigation and completion
- **Blade templates**: Laravel string navigation
- **JavaScript/TypeScript**: Inertia navigation in Laravel projects

## 📦 Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "your-username/laravel.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
  },
  config = function()
    require('laravel').setup()
  end,
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  'your-username/laravel.nvim',
  requires = 'nvim-lua/plenary.nvim',
  config = function()
    require('laravel').setup()
  end
}
```

## ⚙️ Configuration

### Basic Setup

```lua
require('laravel').setup()
```

### Completion Engine Integration

#### For [blink.nvim](https://github.com/saghen/blink.cmp) users:

```lua
require('blink.cmp').setup({
  sources = {
    default = { "laravel", "lsp", "path", "snippets", "buffer" },
    providers = {
      laravel = {
        name = "Laravel",
        module = "laravel.blink_source",
        enabled = function()
          return vim.bo.filetype == 'php' or vim.bo.filetype == 'blade'
        end,
        kind = "Laravel",
        score_offset = 1000, -- Highest priority
        min_keyword_length = 1,
      },
    },
  },
})
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

## 🎮 Usage

### Navigation

1. **Place your cursor** on any Laravel string reference
2. **Press `gd`** to navigate to the corresponding file
3. **Enjoy instant navigation** with automatic file detection and key searching

### Completion

1. **Start typing** a Laravel helper function: `route('`, `view('`, etc.
2. **See Laravel completions** appear first in your completion list
3. **Select and insert** the desired completion

### Commands

- `:LaravelTestCompletions` - Test the completion system
- `:LaravelCompletions [type]` - Show completions for a specific type (route, view, config, trans)
- `:LaravelClearCache` - Clear the completion cache

## 🏗️ How It Works

### Smart Pattern Detection
The plugin uses intelligent pattern matching to detect Laravel helper functions and extract the complete string content, regardless of cursor position.

### Context-Aware Navigation
Based on the detected Laravel function, the plugin:
1. **Routes**: Searches `routes/*.php` files for named route definitions
2. **Views**: Checks `resources/views/*.blade.php` and `resources/js/Pages/*` for components
3. **Config**: Opens `config/*.php` files and searches for specific keys
4. **Translations**: Opens `lang/en/*.php` files and finds translation keys

### Fallback System
If not in a Laravel context, the plugin gracefully falls back to:
1. **LSP definition** (if available)
2. **Built-in `gd`** behavior

### Performance
- **30-second caching** for completion data
- **Lazy loading** of Laravel project detection
- **Efficient pattern matching** with minimal overhead

## 🛠️ Requirements

- **Neovim** 0.8.0+
- **Laravel project** with standard directory structure
- **Optional**: LSP server for non-Laravel definitions
- **Optional**: Completion engine (blink.nvim or nvim-cmp)

## 🎯 Supported Laravel Versions

This plugin works with any Laravel version that follows the standard directory structure:

- ✅ Laravel 8+
- ✅ Laravel 9+  
- ✅ Laravel 10+
- ✅ Laravel 11+

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

Inspired by Laravel Idea for PhpStorm, bringing similar functionality to the Neovim ecosystem.
