# Laravel.nvim

A comprehensive Neovim plugin for Laravel development that provides intelligent PHP LSP integration, Blade template support, Artisan command execution, and seamless navigation between Laravel components.

## ✨ Features

### 🚀 Laravel-Specific Navigation
- Smart navigation between Controllers, Models, Views, and Migrations
- Context-aware file jumping based on current cursor position
- Quick access to related files (Controller ↔ Model ↔ View ↔ Migration)

### 🎨 Blade Template Support
- Full Blade syntax highlighting and indentation
- Comprehensive snippet collection for Blade directives
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
- Model-specific snippets for relationships, scopes, and accessors

### 🗄️ Migration Tools
- Migration file navigation and analysis
- Parse table operations and column definitions
- Database migration command shortcuts
- Migration-specific snippets

### 🔧 LSP Integration
- Automatic PHP language server setup (Phpactor/Intelephense)
- Laravel-specific LSP enhancements
- Blade template LSP support
- Intelligent diagnostics and completions

### 🎨 Modern UI Integration
- Optional [Snacks.nvim](https://github.com/folke/snacks.nvim/) integration for enhanced UI
- Beautiful fuzzy finding with modern picker interface
- Enhanced notifications and floating windows
- Graceful fallback to built-in vim.ui when snacks.nvim is not available

## 📦 Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  'adibhanna/laravel.nvim',
  ft = { 'php', 'blade' },
  dependencies = {
    'folke/snacks.nvim', -- Optional: for enhanced UI
  },
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
  requires = {
    'folke/snacks.nvim', -- Optional
  },
  config = function()
    -- Auto-setup on Laravel project detection
  end,
}
```

## ⚙️ Prerequisites

### Required
- **Neovim 0.10+** (for built-in snippet support)
- **PHP 8.0+**
- **Composer** (for Laravel projects)

### Recommended
- **PHP Language Server**: Install one of the following:
  ```bash
  # Phpactor (recommended)
  composer global require phpactor/phpactor
  
  # OR Intelephense
  npm install -g intelephense
  ```

- **HTML Language Server** (for Blade files):
  ```bash
  npm install -g vscode-langservers-extracted
  ```

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

#### Global (in Laravel projects)
- `<leader>lc` - Go to controller
- `<leader>lm` - Go to model  
- `<leader>lv` - Go to view
- `<leader>lr` - Show routes

#### In Model Files
- `<leader>mr` - Show model relationships
- `<leader>ma` - Show model attributes
- `<leader>mg` - Go to related model

#### In Migration Files
- `<leader>mi` - Show migration info
- `<leader>mm` - Run migration command

#### In Route Files
- `<leader>rt` - Test route at cursor
- `gd` - Go to route definition (or LSP definition)

### Snippets

#### Blade Templates
- `@if` → `@if($condition) ... @endif`
- `@foreach` → `@foreach($items as $item) ... @endforeach`
- `@extends` → `@extends('layout')`
- `@section` → `@section('name') ... @endsection`
- And many more Laravel Blade directives!

#### PHP Models
- `hasOne` → `public function relationName() { return $this->hasOne(Model::class); }`
- `belongsTo` → `public function relationName() { return $this->belongsTo(Model::class); }`
- `scope` → Query scope method
- `mutator` → Attribute mutator
- `accessor` → Attribute accessor

#### Migrations
- `string` → `$table->string('column_name');`
- `foreign` → `$table->foreign('column')->references('id')->on('table');`
- `timestamps` → `$table->timestamps();`
- And all Laravel migration column types!

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
    lsp = true,
  },
  
  -- LSP server preference
  lsp_server = 'phpactor', -- or 'intelephense'
  
  -- UI preferences
  ui = {
    use_snacks = true, -- Use Snacks.nvim for selections if available
  },
}
```

## 🔌 Integration

### Snacks.nvim
Laravel.nvim integrates seamlessly with [Snacks.nvim](https://github.com/folke/snacks.nvim/) for enhanced UI:
- Beautiful picker interface for selections with fuzzy finding
- Enhanced notifications for better user feedback
- Consistent UI experience across all Laravel operations
- Modern floating windows for route browsing and file selection
- Better performance compared to traditional pickers

### Tree-sitter
Blade syntax highlighting works with tree-sitter when available.

### LSP Clients
Works with popular LSP configurations like:
- `nvim-lspconfig`
- `mason.nvim`
- Built-in Neovim LSP

## 🐛 Troubleshooting

### PHP Language Server Not Found
```bash
# Install Phpactor
composer global require phpactor/phpactor

# OR install Intelephense
npm install -g intelephense

# Make sure global composer bin is in PATH
export PATH="$HOME/.composer/vendor/bin:$PATH"
```

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