# Laravel.nvim

A comprehensive Neovim plugin for Laravel development that provides intelligent PHP LSP integration, Blade template support, Artisan command execution, and seamless navigation between Laravel components.

## ✨ Features

### 🚀 Laravel-Specific Navigation
- Smart navigation between Controllers, Models, Views, and Migrations
- Context-aware file jumping based on current cursor position
- Quick access to related files (Controller ↔ Model ↔ View ↔ Migration)

### 🎨 Blade Template Support
- Full Blade syntax highlighting and indentation

- Laravel helper function completions
- Blade-specific file type detection

### ⚡ Artisan Integration
- Execute any Artisan command directly from Neovim
- Interactive make commands with fuzzy finder
- Cached command completions for better performance
- Terminal integration for long-running commands

### 🔍 Route Management
- View all routes in a formatted floating window
- Navigate directly to route definitions
- Route-aware navigation and completion

### 🏗️ Model Analysis
- Parse and display model relationships
- Show fillable attributes, hidden fields, and casts
- Navigate between related models


### 🗄️ Migration Tools
- Migration file navigation and analysis
- Parse table operations and column definitions
- Database migration command shortcuts


### 🎨 Clean Integration
- Uses standard Neovim UI components for maximum compatibility
- No LSP configuration conflicts - works with your existing setup
- Lightweight and focused on Laravel-specific functionality
- Graceful fallback behaviors for robust operation

## 📦 Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  'adibhanna/laravel.nvim',
  ft = { 'php', 'blade' },
  config = function()
    -- Plugin will auto-configure when entering a Laravel project
  end,
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  'adibhanna/laravel.nvim',
  ft = { 'php', 'blade' },
  config = function()
    -- Auto-setup on Laravel project detection
  end,
}
```

## ⚙️ Prerequisites

### Required
- **Neovim 0.10+**
- **PHP 8.0+**
- **Composer** (for Laravel projects)

## 🚀 Usage

Laravel.nvim automatically activates when you open a Laravel project (detected by the presence of `artisan` file).

### Commands

| Command                     | Description                          |
| --------------------------- | ------------------------------------ |
| `:Artisan [command]`        | Run Artisan commands with completion |
| `:LaravelController [name]` | Navigate to controller               |
| `:LaravelModel [name]`      | Navigate to model                    |
| `:LaravelView [name]`       | Navigate to view                     |
| `:LaravelRoute`             | Show all routes                      |
| `:LaravelMake [type]`       | Interactive make command             |

### Key Mappings

All Laravel keymaps use the `<leader>L` prefix for better organization and to avoid conflicts.

#### Global Laravel Commands
- `<leader>Lc` - Go to controller
- `<leader>Lm` - Go to model  
- `<leader>Lv` - Go to view
- `<leader>LV` - Show related views (context-aware)
- `<leader>Lr` - Show routes
- `<leader>La` - Run artisan command
- `<leader>Lk` - Laravel make command
- `<leader>Ls` - Show Laravel status


#### Model-Specific (in model files)
- `<leader>LR` - Show model relationships
- `<leader>LA` - Show model attributes


#### Migration-Specific (in migration files)
- `<leader>Li` - Show migration info
- `<leader>LM` - Run migration command

#### Route Files
- `gd` - Go to route definition (or LSP definition)



## ⚡ Smart Navigation

Laravel.nvim provides intelligent navigation based on context:

1. **From Controllers**: Navigate to related models and views
2. **From Models**: Jump to controllers, migrations, and related models
3. **From Views**: Find corresponding controllers
4. **From Route Files**: Navigate to controller actions
5. **Cursor-based**: Navigate to classes/views under cursor

## 🎯 Laravel Project Structure

The plugin understands standard Laravel project structure:

```
laravel-project/
├── app/
│   ├── Http/Controllers/    # Controllers
│   ├── Models/             # Models (Laravel 8+)
│   └── *.php               # Models (Laravel < 8)
├── resources/views/        # Blade templates
├── routes/                 # Route definitions
├── database/migrations/    # Migrations
└── artisan                 # Artisan CLI
```

## 🔧 Configuration

Laravel.nvim works out of the box with sensible defaults. For advanced configuration:

```lua
-- Optional: Configure in your init.lua
vim.g.laravel_nvim_config = {
  -- Disable specific features
  features = {
    artisan = true,
    blade = true,
    routes = true,
    models = true,
    migrations = true,
    keymaps = true,
  },
  
  -- UI preferences
  ui = {
    use_fallback_select = true, -- Use vim.ui.select for compatibility
  },
}
```

## 🔌 Integration

### UI Framework
Laravel.nvim uses standard Neovim UI components (`vim.ui.select`, `vim.notify`) for maximum compatibility with your existing setup.

### Tree-sitter
Blade syntax highlighting works with tree-sitter when available.

### LSP Compatibility
Laravel.nvim focuses on Laravel-specific functionality and does not configure LSP servers, allowing you to use your preferred LSP setup:
- Works alongside any PHP LSP configuration
- Compatible with `nvim-lspconfig`, `mason.nvim`, or manual LSP setup
- Provides Laravel-specific navigation and utilities without interfering with LSP

## 🐛 Troubleshooting

### Blade Files Not Highlighting
1. Ensure file extension is `.blade.php`
2. Check that Laravel project is detected (`:echo _G.laravel_nvim.is_laravel_project`)
3. Reload the file or restart Neovim

### Artisan Commands Not Working
1. Verify you're in a Laravel project root
2. Check that `artisan` file exists and is executable
3. Ensure PHP is available in PATH

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Laravel community for the amazing framework
- Neovim team for the powerful editor
- Contributors to PHP language servers and related tools

---

**Happy Laravel coding with Neovim! 🚀** 